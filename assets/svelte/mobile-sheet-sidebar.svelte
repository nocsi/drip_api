<script lang="ts">
	import * as Sheet from '$lib/ui/sheet';
	import { Button } from '$lib/ui/button';
	import { Menu, Home, FileText, Database, Code, Terminal, Globe, Settings, LogOut } from '@lucide/svelte';
	import { ScrollArea } from '$lib/ui/scroll-area';
	import { Badge } from '$lib/ui/badge';

	interface SidebarNavItem {
		title: string;
		href?: string;
		disabled?: boolean;
		external?: boolean;
		icon?: string;
		badge?: string;
		items?: SidebarNavItem[];
	}

	interface Props {
		links: SidebarNavItem[];
		currentPath?: string;
		live?: any;
		siteName?: string;
	}

	let { links = [], currentPath = '', live, siteName = 'Kyozo' }: Props = $props();

	let open = $state(false);
	let isMobile = $state(true);

	// Simple media query check
	function checkScreenSize() {
		if (typeof window !== 'undefined') {
			isMobile = window.innerWidth < 768;
		}
	}

	// Check screen size on mount and resize
	$effect(() => {
		if (typeof window !== 'undefined') {
			checkScreenSize();
			window.addEventListener('resize', checkScreenSize);
			return () => window.removeEventListener('resize', checkScreenSize);
		}
	});

	// Get current path from window or prop
	let path = $derived(() => {
		if (currentPath) return currentPath;
		if (typeof window !== 'undefined') {
			return window.location.pathname;
		}
		return '';
	});

	// Icon mapping
	const iconMap: Record<string, any> = {
		home: Home,
		file: FileText,
		database: Database,
		code: Code,
		terminal: Terminal,
		globe: Globe,
		settings: Settings,
		logout: LogOut,
	};

	function getIcon(iconName?: string) {
		if (!iconName) return FileText;
		return iconMap[iconName.toLowerCase()] || FileText;
	}

	function handleNavigation(href: string, disabled: boolean) {
		if (disabled) return;
		
		open = false;
		
		// If live socket is available, use LiveView navigation
		if (live && live.pushPatch) {
			live.pushPatch(href);
		} else if (typeof window !== 'undefined') {
			// Fallback to regular navigation
			window.location.href = href;
		}
	}

	function cn(...classes: (string | undefined | null | boolean)[]): string {
		return classes.filter(Boolean).join(' ');
	}
</script>

{#if isMobile}
	<Sheet.Root bind:open>
		<Sheet.Trigger>
			<Button variant="outline" size="icon" class="size-9 shrink-0 md:hidden">
				<Menu class="size-5" />
				<span class="sr-only">Toggle navigation menu</span>
			</Button>
		</Sheet.Trigger>
		<Sheet.Content side="left" class="flex flex-col p-0 w-80">
			<ScrollArea class="h-full overflow-y-auto">
				<div class="flex h-screen flex-col">
					<nav class="flex flex-1 flex-col gap-y-6 p-6 text-lg font-medium">
						<!-- Logo/Brand -->
						<button
							type="button"
							onclick={() => handleNavigation('/', false)}
							class="flex items-center gap-2 text-lg font-semibold hover:opacity-80 transition-opacity"
						>
							<div class="w-8 h-8 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
								<span class="text-white font-bold text-sm">K</span>
							</div>
							<span class="font-bold text-xl">
								{siteName}
							</span>
						</button>
						
						<!-- Navigation Links -->
						{#each links as section}
							<section class="flex flex-col gap-1">
								{#if section.title}
									<p class="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-2">
										{section.title}
									</p>
								{/if}

								{#if section.items}
									{#each section.items as item}
										{#if item.href}
											<button
												type="button"
												onclick={() => handleNavigation(item.href || '', item.disabled || false)}
												class={cn(
													'flex items-center gap-3 rounded-md p-3 text-sm font-medium hover:bg-muted text-left w-full transition-colors',
													path() === item.href
														? 'bg-muted text-foreground'
														: 'text-muted-foreground hover:text-foreground',
													item.disabled &&
														'cursor-not-allowed opacity-50 hover:bg-transparent hover:text-muted-foreground'
												)}
												disabled={item.disabled}
											>
												<svelte:component this={getIcon(item.icon)} class="size-5 flex-shrink-0" />
												<span class="flex-1">{item.title}</span>
												{#if item.badge}
													<Badge
														variant="secondary"
														class="ml-auto flex size-5 shrink-0 items-center justify-center rounded-full text-xs"
													>
														{item.badge}
													</Badge>
												{/if}
											</button>
										{:else}
											<!-- Non-clickable item -->
											<div
												class={cn(
													'flex items-center gap-3 rounded-md p-3 text-sm font-medium',
													'text-muted-foreground opacity-60'
												)}
											>
												<svelte:component this={getIcon(item.icon)} class="size-5 flex-shrink-0" />
												<span class="flex-1">{item.title}</span>
												{#if item.badge}
													<Badge
														variant="secondary"
														class="ml-auto flex size-5 shrink-0 items-center justify-center rounded-full text-xs"
													>
														{item.badge}
													</Badge>
												{/if}
											</div>
										{/if}
									{/each}
								{:else if section.href}
									<!-- Single item section -->
									<button
										type="button"
										onclick={() => handleNavigation(section.href || '', section.disabled || false)}
										class={cn(
											'flex items-center gap-3 rounded-md p-3 text-sm font-medium hover:bg-muted text-left w-full transition-colors',
											path() === section.href
												? 'bg-muted text-foreground'
												: 'text-muted-foreground hover:text-foreground',
											section.disabled &&
												'cursor-not-allowed opacity-50 hover:bg-transparent hover:text-muted-foreground'
										)}
										disabled={section.disabled}
									>
										<svelte:component this={getIcon(section.icon)} class="size-5 flex-shrink-0" />
										<span class="flex-1">{section.title}</span>
										{#if section.badge}
											<Badge
												variant="secondary"
												class="ml-auto flex size-5 shrink-0 items-center justify-center rounded-full text-xs"
											>
												{section.badge}
											</Badge>
										{/if}
									</button>
								{/if}
							</section>
						{/each}
					</nav>
				</div>
			</ScrollArea>
		</Sheet.Content>
	</Sheet.Root>
{/if}