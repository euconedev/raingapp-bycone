// Helper functions miscelâneas

export function isEnvBrowser(): boolean {
    return !(window as any).invokeNative;
}

export function formatTime(ms: number): string {
    const minutes = Math.floor(ms / 60000);
    const seconds = ((ms % 60000) / 1000).toFixed(3);
    return `${minutes}:${seconds.padStart(6, '0')}`;
}

export function formatSpeed(speed: number): string {
    return `${Math.round(speed)} km/h`;
}

export function clamp(value: number, min: number, max: number): number {
    return Math.min(Math.max(value, min), max);
}

export function debounce<T extends (...args: any[]) => any>(
    func: T,
    wait: number
): (...args: Parameters<T>) => void {
    let timeout: NodeJS.Timeout;
    return (...args: Parameters<T>) => {
        clearTimeout(timeout);
        timeout = setTimeout(() => func(...args), wait);
    };
}

// Funções adicionais que podem ser necessárias
export function noop(): void {
    // Do nothing
}

export function generateId(): string {
    return Math.random().toString(36).substr(2, 9);
}
