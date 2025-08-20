<script lang="ts">
	import { cn } from "$lib/utils.js";

	let {
		ref = $bindable(null),
		class: className,
		placeholder = "Select an option...",
		...restProps
	}: {
		ref?: HTMLElement | null;
		class?: string;
		placeholder?: string;
		[key: string]: any;
	} = $props();
</script>

<span
	bind:this={ref}
	class={cn("block truncate text-sm text-muted-foreground", className)}
	{...restProps}
>
	{placeholder}
	<slot />
</span>