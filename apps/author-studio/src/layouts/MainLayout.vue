<template>
  <q-layout view="lHh Lpr lFf">
    <q-header elevated>
      <q-toolbar>
        <q-btn flat dense round icon="menu" aria-label="Menu" @click="toggleLeftDrawer" />
        <q-toolbar-title> Poetry Platform </q-toolbar-title>
      </q-toolbar>
    </q-header>

    <q-drawer v-model="leftDrawerOpen" bordered>
      <q-list>
        <q-item-label header> Navigation </q-item-label>
      </q-list>
    </q-drawer>

    <q-page-container>
      <div class="row q-pa-md" style="height: calc(100vh - 50px)">
        <div class="col-6 q-pr-sm" style="height: 100%">
          <OpusTextEditor :orchestrator="orchestrator" />
        </div>
        <div class="col-6 q-pl-sm" style="height: 100%">
          <VisualizerContainer :orchestrator="orchestrator" />
        </div>
      </div>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { Orchestrator } from '@poetry/editor-engine';
import OpusTextEditor from 'components/OpusTextEditor/OpusTextEditor.vue';
import VisualizerContainer from 'components/VisualizerContainer/VisualizerContainer.vue';

const orchestrator = new Orchestrator();
const leftDrawerOpen = ref(false);

function toggleLeftDrawer() {
  leftDrawerOpen.value = !leftDrawerOpen.value;
}
</script>
