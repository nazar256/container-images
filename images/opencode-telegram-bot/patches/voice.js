import http from "node:http";
import https from "node:https";
import { URL } from "node:url";
import { HttpsProxyAgent } from "https-proxy-agent";
import { SocksProxyAgent } from "socks-proxy-agent";
import { config } from "../../config.js";
import { isSttConfigured, transcribeAudio } from "../../stt/client.js";
import { processUserPrompt } from "./prompt.js";
import { logger } from "../../utils/logger.js";
import { t } from "../../i18n/index.js";
const TELEGRAM_DOWNLOAD_TIMEOUT_MS = 30_000;
const TELEGRAM_DOWNLOAD_MAX_REDIRECTS = 3;
const SUPPORTED_STT_EXTENSIONS = new Set(["flac", "mp3", "mp4", "mpeg", "mpga", "m4a", "ogg", "opus", "wav", "webm"]);
let telegramDownloadAgent;
function getExtensionFromMimeType(mimeType) {
    if (!mimeType) {
        return null;
    }
    const normalized = mimeType.toLowerCase().split(";")[0].trim();
    switch (normalized) {
        case "audio/flac":
            return "flac";
        case "audio/mpeg":
            return "mp3";
        case "audio/mp4":
            return "mp4";
        case "audio/mpga":
            return "mpga";
        case "audio/x-m4a":
        case "audio/m4a":
            return "m4a";
        case "audio/ogg":
            return "ogg";
        case "audio/opus":
            return "opus";
        case "audio/wav":
        case "audio/x-wav":
            return "wav";
        case "audio/webm":
            return "webm";
        default:
            return null;
    }
}
function normalizeAudioFilename(inputFilename, fallbackExtension) {
    const safeFallback = (fallbackExtension || "ogg").replace(/^\./, "").toLowerCase();
    const fallback = SUPPORTED_STT_EXTENSIONS.has(safeFallback) ? safeFallback : "ogg";
    const candidate = (inputFilename || "").trim();
    if (!candidate) {
        return `audio.${fallback}`;
    }
    const baseName = candidate.split(/[\\/]/).pop() || "audio";
    const dotIndex = baseName.lastIndexOf(".");
    const stem = dotIndex > 0 ? baseName.slice(0, dotIndex) : baseName;
    const rawExt = dotIndex > -1 ? baseName.slice(dotIndex + 1).toLowerCase() : "";
    const normalizedExt = rawExt === "oga" ? "ogg" : rawExt;
    const finalExt = SUPPORTED_STT_EXTENSIONS.has(normalizedExt) ? normalizedExt : fallback;
    return `${stem || "audio"}.${finalExt}`;
}
function getTelegramDownloadAgent() {
    if (telegramDownloadAgent !== undefined) {
        return telegramDownloadAgent || undefined;
    }
    const proxyUrl = config.telegram.proxyUrl.trim();
    if (!proxyUrl) {
        telegramDownloadAgent = null;
        return undefined;
    }
    telegramDownloadAgent = proxyUrl.startsWith("socks")
        ? new SocksProxyAgent(proxyUrl)
        : new HttpsProxyAgent(proxyUrl);
    logger.info(`[Voice] Using Telegram download proxy: ${proxyUrl.replace(/\/\/.*@/, "//***@")}`);
    return telegramDownloadAgent;
}
async function downloadTelegramFileByUrl(url, redirectDepth = 0) {
    return new Promise((resolve, reject) => {
        const targetUrl = new URL(url);
        const requestModule = targetUrl.protocol === "http:" ? http : https;
        const request = requestModule.get(targetUrl, { agent: getTelegramDownloadAgent() }, (response) => {
            const statusCode = response.statusCode ?? 0;
            if (statusCode >= 300 && statusCode < 400 && response.headers.location) {
                response.resume();
                if (redirectDepth >= TELEGRAM_DOWNLOAD_MAX_REDIRECTS) {
                    reject(new Error("Too many redirects while downloading Telegram file"));
                    return;
                }
                const redirectUrl = new URL(response.headers.location, targetUrl).toString();
                void downloadTelegramFileByUrl(redirectUrl, redirectDepth + 1)
                    .then(resolve)
                    .catch(reject);
                return;
            }
            if (statusCode < 200 || statusCode >= 300) {
                response.resume();
                reject(new Error(`Telegram file download failed with HTTP ${statusCode}`));
                return;
            }
            const chunks = [];
            response.on("data", (chunk) => {
                chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
            });
            response.on("end", () => {
                resolve(Buffer.concat(chunks));
            });
            response.on("error", reject);
        });
        request.on("error", reject);
        request.setTimeout(TELEGRAM_DOWNLOAD_TIMEOUT_MS, () => {
            request.destroy(new Error(`Telegram file download timed out after ${TELEGRAM_DOWNLOAD_TIMEOUT_MS}ms`));
        });
    });
}
/**
 * Downloads the audio file from Telegram servers.
 *
 * @returns Buffer with file content, or null on failure
 */
async function downloadTelegramFile(ctx, fileId) {
    try {
        const file = await ctx.api.getFile(fileId);
        if (!file.file_path) {
            logger.error("[Voice] Telegram getFile returned no file_path");
            return null;
        }
        const fileUrl = `https://api.telegram.org/file/bot${ctx.api.token}/${file.file_path}`;
        logger.debug(`[Voice] Downloading file: ${file.file_path} (${file.file_size ?? "?"} bytes)`);
        const buffer = await downloadTelegramFileByUrl(fileUrl);
        // Extract filename from file_path (e.g., "voice/file_123.oga" -> "file_123.oga")
        const filename = file.file_path.split("/").pop() || "audio.ogg";
        logger.debug(`[Voice] Downloaded file: ${filename} (${buffer.length} bytes)`);
        return { buffer, filename };
    }
    catch (err) {
        logger.error("[Voice] Error downloading file from Telegram:", err);
        return null;
    }
}
/**
 * Creates the voice message handler function.
 *
 * The factory pattern is used so that `bot` and `ensureEventSubscription` dependencies
 * can be injected from createBot() without circular imports.
 */
export function createVoiceHandler(deps) {
    return async (ctx) => {
        await handleVoiceMessage(ctx, deps);
    };
}
/**
 * Handles incoming voice and audio messages:
 * 1. Checks if STT is configured
 * 2. Downloads the audio file from Telegram
 * 3. Sends "recognizing..." status message
 * 4. Calls STT API
 * 5. Shows recognized text
 * 6. Passes text to processUserPrompt
 */
export async function handleVoiceMessage(ctx, deps) {
    const sttConfigured = deps.isSttConfigured ?? isSttConfigured;
    const downloadFile = deps.downloadTelegramFile ?? downloadTelegramFile;
    const transcribe = deps.transcribeAudio ?? transcribeAudio;
    const processPrompt = deps.processPrompt ?? processUserPrompt;
    // Determine file_id from voice or audio message
    const voice = ctx.message?.voice;
    const audio = ctx.message?.audio;
    const fileId = voice?.file_id ?? audio?.file_id;
    const fallbackExt = voice ? "ogg" : (getExtensionFromMimeType(audio?.mime_type) ?? "mp3");
    const fallbackFilename = normalizeAudioFilename(audio?.file_name ?? (voice ? `voice_${fileId}.ogg` : `audio_${fileId}`), fallbackExt);
    if (!fileId) {
        logger.warn("[Voice] Received voice/audio message with no file_id");
        return;
    }
    // Check if STT is configured
    if (!sttConfigured()) {
        await ctx.reply(t("stt.not_configured"));
        return;
    }
    // Send "recognizing..." status message (will be edited later)
    const statusMessage = await ctx.reply(t("stt.recognizing"));
    try {
        // Download the audio file from Telegram
        const fileData = await downloadFile(ctx, fileId);
        if (!fileData) {
            await ctx.api.editMessageText(ctx.chat.id, statusMessage.message_id, t("stt.error", { error: "download failed" }));
            return;
        }
        // Transcribe the audio
        const transcribeFilename = normalizeAudioFilename(audio?.file_name ?? fileData.filename ?? fallbackFilename, fallbackExt);
        const result = await transcribe(fileData.buffer, transcribeFilename);
        const recognizedText = result.text.trim();
        if (!recognizedText) {
            await ctx.api.editMessageText(ctx.chat.id, statusMessage.message_id, t("stt.empty_result"));
            return;
        }
        // Show the recognized text by editing the status message.
        // IMPORTANT: even if this edit fails (e.g. Telegram message length limits),
        // we still send the recognized text to OpenCode as a prompt.
        try {
            await ctx.api.editMessageText(ctx.chat.id, statusMessage.message_id, t("stt.recognized", { text: recognizedText }));
        }
        catch (editError) {
            logger.warn("[Voice] Failed to edit status message with recognized text:", editError);
        }
        logger.info(`[Voice] Transcribed audio: ${recognizedText.length} chars`);
        // Process the recognized text as a prompt
        await processPrompt(ctx, recognizedText, deps);
    }
    catch (err) {
        const errorMessage = err instanceof Error ? err.message : "unknown error";
        logger.error("[Voice] Error processing voice message:", err);
        try {
            await ctx.api.editMessageText(ctx.chat.id, statusMessage.message_id, t("stt.error", { error: errorMessage }));
        }
        catch {
            // If we can't edit the status message, try sending a new one
            await ctx.reply(t("stt.error", { error: errorMessage })).catch(() => { });
        }
    }
}
