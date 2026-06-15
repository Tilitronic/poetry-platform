<template>
  <div>Instrument panel</div>
  <div ref="editorRef" class="opus-text-editor" />
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { Orchestrator, OpusEditorView } from '@poetry/editor-engine';

const props = defineProps<{ orchestrator?: Orchestrator }>();
const editorRef = ref<HTMLElement | null>(null);
let view: OpusEditorView | null = null;
const orchestrator = props.orchestrator ?? new Orchestrator();

onMounted(() => {
  if (!editorRef.value) return;
  view = new OpusEditorView(editorRef.value, orchestrator);
});

onUnmounted(() => {
  view?.destroy();
});
</script>

<style scoped>
.opus-text-editor {
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  background: #fff;
  height: 100%;
}
</style>
