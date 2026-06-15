<template>
  <q-card flat bordered class="column fill-height">
    <q-tabs
      v-model="activeTab"
      dense
      class="text-grey"
      active-color="primary"
      indicator-color="primary"
      align="justify"
      narrow-indicator
    >
      <q-tab name="2d" icon="blur_on" label="2D Spectrum" />
      <q-tab name="3d" icon="explore" label="3D Space" />
    </q-tabs>

    <q-separator />

    <q-tab-panels v-model="activeTab" animated class="col bg-grey-1">
      <q-tab-panel name="2d" class="q-pa-none">
        <div id="poetry-d3-viewport" style="height: 100%; min-height: 400px"></div>
      </q-tab-panel>

      <q-tab-panel name="3d" class="q-pa-none flex flex-center">
        <AsyncVisualizer3D :orchestrator="props.orchestrator" />
      </q-tab-panel>
    </q-tab-panels>
  </q-card>
</template>

<script setup lang="ts">
import { ref, onMounted, defineAsyncComponent, watch } from 'vue';
import { initInteractiveVisualizer } from '@poetry/visualizer-2d';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const props = defineProps<{ orchestrator: any }>();
const activeTab = ref('2d');
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let visualizer2D: any = null;

// Dynamic (async) import of the 3D package.
// Vite automatically splits @poetry/visualizer-3d into a separate .js chunk
const AsyncVisualizer3D = defineAsyncComponent(() => import('@poetry/visualizer-3d'));

onMounted(() => {
  // Initialize lightweight D3 immediately
  visualizer2D = initInteractiveVisualizer('#poetry-d3-viewport', props.orchestrator);
});

// Re-render 2D when user navigates back from 3D tab
watch(activeTab, (newTab) => {
  if (newTab === '2d' && visualizer2D) {
    visualizer2D.update();
  }
});
</script>
