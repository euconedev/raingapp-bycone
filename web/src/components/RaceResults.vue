<template>
  <div class="race-results-container">
    <h3>Resultados das Corridas Recentes</h3>
    <div v-if="loading">Carregando resultados...</div>
    <div v-else-if="error">Erro ao carregar resultados: {{ error }}</div>
    <div v-else-if="raceResults && raceResults.length > 0">
      <ul>
        <li v-for="result in raceResults" :key="result.id">
          {{ result.raceName }} - {{ result.winner }} - {{ result.time }}
        </li>
      </ul>
    </div>
    <div v-else>Nenhum resultado de corrida encontrado.</div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import api from "@/api/axios";

const raceResults = ref<any[]>([]);
const loading = ref(true);
const error = ref<string | null>(null);

const fetchRaceResults = async () => {
  try {
    loading.value = true;
    const response = await api.post("UiGetRacingResults");
    if (response.data) {
      raceResults.value = response.data;
    }
  } catch (err: any) {
    error.value = err.message;
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchRaceResults();
});
</script>

<style scoped>
.race-results-container {
  padding: 1em;
}
</style>