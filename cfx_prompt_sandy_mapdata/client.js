const resourceName = GetCurrentResourceName();

// Max time (ms) spent registering streaming files per tick, to avoid hitches.
const FRAME_BUDGET_MS = 2;

const nextTick = () => new Promise((resolve) => setTimeout(resolve, 0));

let registered = false;

onNet('registerVertexHubResources/cfx_prompt_sandy_mapdata', async (resourcesDto) => {
    if (registered) return;
    registered = true;

    const resources = JSON.parse(resourcesDto);
    let frameStart = GetGameTimer();

    for (const { fileName, cacheString } of resources) {
        RegisterStreamingFileFromCache(resourceName, fileName, cacheString);

        if (GetGameTimer() - frameStart >= FRAME_BUDGET_MS) {
            await nextTick();
            frameStart = GetGameTimer();
        }
    }
});

emitNet('requestVertexHubResources/cfx_prompt_sandy_mapdata');
