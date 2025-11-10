<template>
  <div id="ResultsPage" class="page-container">
    <Tabs v-model="tab" class="flex-1">
      <div class=" flex items-center justify-between">
        <TabsList>
          <TabsTrigger @click="setTab('results')" value="results">Corridas Recentes</TabsTrigger>
          <TabsTrigger @click="setTab('crewRank')" value="crewRank">{{ translate('crew_rankings') }}</TabsTrigger>
          <TabsTrigger @click="setTab('racerRank')" value="racerRank">{{ translate('racer_rankings') }}</TabsTrigger>
          <TabsTrigger @click="setTab('records')" value="records">{{ translate('track_records') }}</TabsTrigger>
        </TabsList>
        <div class="flex items-center gap-2">
          <Label for="curated-switch">{{ translate('curated_only') }}</Label>
          <Switch
            :model-value="globalStore.showOnlyCurated"
            :id="'curated-switch'"
            @update:model-value="() => { globalStore.showOnlyCurated = !globalStore.showOnlyCurated }"
          ></Switch>
        </div>
      </div>
      <TabsContent value="results">
        <RaceResults />
      </TabsContent>
      <TabsContent value="crewRank">
        <CrewTable />
      </TabsContent>
      <TabsContent value="racerRank">
        <RacersTable />
      </TabsContent>
      <TabsContent value="records">
        <div class="flex flex-col gap-5">
          <div class="flex items-center gap-2">
            <Select v-model="selectedTrack">
              <SelectTrigger class="w-[250px]">
                <SelectValue placeholder="Seleciona Pista" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="track in tracks" :value="track.name">
                  {{ track.name }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="flex flex-col gap-2" v-if="trackRecords.length > 0">
            <div v-for="record in trackRecords" :key="record.id">
              {{ record.playerName }} - {{ record.time }}
            </div>
          </div>
          <div v-else>
            <p>{{ translate('select_track_to_view') }}</p>
          </div>
        </div>
      </TabsContent>
    </Tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, computed, Ref } from "vue";
import RaceResults from "../components/RaceResults.vue";
import CrewTable from "../components/CrewRankings.vue";
import RacersTable from "../components/RacersRankings.vue";
import { translate } from "@/helpers/translate";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { useGlobalStore } from "@/store/global";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { api } from "@/api";
import { Track } from "@/types/Track";
import { testState } from "@/mocking/testState";

const globalStore = useGlobalStore();

const setTab = (newTab: string) => {
  globalStore.currentTab.results = newTab;
};

const tab = ref(globalStore.currentTab.results);

const selectedTrack: Ref<string | undefined> = ref();
const tracks: Ref<Track[]> = ref([]);
const trackRecords: Ref<any[]> = ref([]);

const getMyTracks = async () => {
  tracks.value = await api.getTracks();
  if (tracks.value.length > 0) {
    selectedTrack.value = tracks.value[0].name;
  }
};

const getTrackRecords = async () => {
  if (!selectedTrack.value) return;
  trackRecords.value = await api.getTrackRecords(selectedTrack.value);
};

watch(selectedTrack, () => {
  getTrackRecords();
});

onMounted(() => {
  getMyTracks();
});
</script>

<style scoped>
</style>
