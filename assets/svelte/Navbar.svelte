<script lang="ts">
	import browser from '$lib/utils';
	import { useScroll } from '$lib/stores';
	import MaxWidthWrapper from '$lib/shared/MaxWidthWrapper.svelte';
	import { Icons } from '$lib/shared/icons';
	import { siteConfig } from '$lib/config/site';
	import Button from '$lib/ui/button/button.svelte';
	import { marketingConfig } from '$lib/config/marketing';
	import { cn } from '$lib/utils';

	interface NavBarProps {
		scroll?: boolean;
		large?: boolean;
		children?: any;
	}

	const { scroll = false, large = false, children }: NavBarProps = $props();
	const scrolled = useScroll(50, browser);

	// Set this variable to the current opended layout
	let selectedLayout: string = '';
</script>

<svelte:head>
	<title>svelte-saas-starter</title>
</svelte:head>


<header
	class="sticky top-0 z-40 flex w-full justify-center bg-background/60 backdrop-blur-xl transition-all
    {scroll ? (scrolled ? 'border-b' : 'bg-transparent') : 'border-b'}"
>
	<MaxWidthWrapper class="flex h-14 items-center justify-between">
		<div class="flex gap-6 md:gap-10">
			<a href="/" class="flex items-center space-x-1.5">
				<Icons.logo />
				<span class="font-urban text-xl font-bold">
					{siteConfig.name}
				</span>
			</a>
			<nav class="hidden gap-6 md:flex">
				{#each marketingConfig.mainNav as item}
					<a
						href={item.href}
						class={cn(
							'flex items-center text-lg font-medium transition-colors hover:text-foreground/80 sm:text-sm',
							item.href.startsWith(selectedLayout) ? 'text-foreground' : 'text-foreground/60',
							item.disabled && 'cursor-not-allowed opacity-80'
						)}
					>
						{item.title}
					</a>
				{/each}
			</nav>
		</div>
		<div class="flex items-center space-x-3">
			<Button
			class="hidden gap-2 rounded-full px-5 md:flex"
				href="/sign-in"
				variant="default"
				size="sm"
			>
				<span>Sign In</span>
				<Icons.arrowRight class="size-4" />
			</Button>
		</div>
	</MaxWidthWrapper>
</header>
<div class="flex min-h-screen flex-col">

{@render children?.()}
</div>
