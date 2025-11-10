import { isEnvBrowser } from "@/helpers/misc";

interface NuiMessage {
  post: (eventName: string, data?: any) => Promise<any>;
}

const nui: NuiMessage = {
  post: async (eventName: string, data?: any) => {
    const options = {
      method: "post",
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify(data),
    };

    if (isEnvBrowser()) {
      // Mock data for browser environment
      if (eventName === "GetBaseData") {
        return Promise.resolve({
          data: {
            currentRacerName: "MockRacer",
            currentCrewName: "MockCrew",
            payments: {
              cryptoType: "MOCK",
              racing: "MOCK",
            },
          },
        });
      } else if (eventName === "UiFetchCurrentRace") {
        return Promise.resolve({
          data: {
            raceId: "mock-race-123",
            raceName: "Mock Race",
            racers: 2,
            laps: 3,
            BuyIn: 100,
            ParticipationCurrency: "cash",
            ParticipationAmount: 50,
            Ghosting: true,
            GhostingTime: 5,
          },
        });
      }
      return Promise.resolve({ data: {} });
    }

    const resourceName = (window as any).GetParentResourceName
      ? (window as any).GetParentResourceName()
      : "";

    console.log("NUI: resourceName", resourceName); // Log de depuração
    const url = `https://${resourceName}/${eventName}`;
    console.log("NUI: URL da requisição", url); // Log de depuração

    const resp = await fetch(url, options);

    return await resp.json();
  },
};

export default nui;