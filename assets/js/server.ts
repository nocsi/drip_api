// import * as Components from "../svelte/**/*.svelte"
import {getRender} from "live_svelte"

const modules: Record<string, any> = import.meta.glob('../svelte/**/*.svelte', {
    eager: true
});
const Components = Object.fromEntries(
    Object.entries(modules).map(([key, module]) => [key, (module as any).default])
);

export const render = getRender(Components)
