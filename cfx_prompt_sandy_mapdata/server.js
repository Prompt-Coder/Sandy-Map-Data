const fs = require('fs');
const path = require('path');

const resourceName = GetCurrentResourceName();
const resourcePath = GetResourcePath(resourceName);
const resourceStreamPath = path.join(resourcePath, 'stream');

// Max time (ms) spent registering assets per tick, to avoid server hitches.
const FRAME_BUDGET_MS = 4;

const nextTick = () => new Promise((resolve) => setImmediate(resolve));

const walk = async (dir) => {
    const entries = await fs.promises.readdir(dir, { withFileTypes: true });
    const nested = await Promise.all(entries.map((entry) => {
        const fullPath = path.join(dir, entry.name);
        return entry.isDirectory() ? walk(fullPath) : [fullPath];
    }));
    return nested.flat();
};

let resourcesDto = null;
const pendingPlayers = new Set();

const sendResources = (target) => {
    emitNet('registerVertexHubResources/cfx_prompt_sandy_mapdata', target, resourcesDto);
};

(async () => {
    const resources = [];

    try {
        const streamFiles = await walk(resourceStreamPath);
        let frameStart = Date.now();

        for (const streamFile of streamFiles) {
            const relativePath = path.relative(resourcePath, streamFile);
            const cacheString = RegisterResourceAsset(resourceName, relativePath);

            resources.push({
                fileName: path.basename(streamFile),
                cacheString,
            });

            if (Date.now() - frameStart >= FRAME_BUDGET_MS) {
                await nextTick();
                frameStart = Date.now();
            }
        }
    } catch (err) {
        console.error(`[${resourceName}] failed to register stream assets: ${err}`);
    }

    resourcesDto = JSON.stringify(resources);

    for (const target of pendingPlayers) {
        sendResources(target);
    }
    pendingPlayers.clear();
})();

onNet('requestVertexHubResources/cfx_prompt_sandy_mapdata', () => {
    const target = source;

    if (resourcesDto === null) {
        pendingPlayers.add(target);
        return;
    }

    sendResources(target);
});

on('playerDropped', () => {
    pendingPlayers.delete(source);
});
