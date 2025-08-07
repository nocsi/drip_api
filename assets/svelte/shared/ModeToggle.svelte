<script lang="ts">
	import Sun from '@lucide/svelte/icons/sun';
	import Moon from '@lucide/svelte/icons/moon';

	import { resetMode, setMode } from 'mode-watcher';
	import * as DropdownMenu from '$lib/ui/dropdown-menu/';
	import { Button } from '$lib/ui/button/';
	import { Icons } from '$lib/shared/icons';
</script>

<DropdownMenu.Root>
	<DropdownMenu.Trigger>
		<Button variant="outline" size="icon" class="size-8 px-0">
			<Sun class="rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
			<Moon class="absolute rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
			<span class="sr-only">Toggle theme</span>
		</Button>
	</DropdownMenu.Trigger>
	<DropdownMenu.Content align="end">
		<DropdownMenu.Item onclick={() => setMode('light')}>
			<Icons.sun class="mr-2 size-4" />
			<span>Light</span></DropdownMenu.Item
		>
		<DropdownMenu.Item onclick={() => setMode('dark')}>
			<Icons.moon class="mr-2 size-4" />
			<span>Dark</span></DropdownMenu.Item
		>
		<DropdownMenu.Item onclick={() => resetMode()}>
			<Icons.laptop class="mr-2 size-4" />
			<span>System</span></DropdownMenu.Item
		>
	</DropdownMenu.Content>
</DropdownMenu.Root>