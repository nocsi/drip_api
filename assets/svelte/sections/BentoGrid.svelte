<script lang="ts">
	import { onMount } from 'svelte';
	import { cn } from '$lib/utils';
	import { Card, CardContent } from '$lib/ui/card';
	import { Badge } from '$lib/ui/badge';
	import { Button } from '$lib/ui/button';
	import { 
		Building, 
		Code, 
		Brain, 
		Database, 
		GitBranch, 
		Users, 
		Shield, 
		Cpu, 
		Cloud,
		Zap,
		Terminal,
		Globe,
		FileText,
		BarChart3,
		Sparkles,
		ArrowRight
	} from '@lucide/svelte';
	
	let mounted = $state(false);
	let hoveredCard = $state(null);
	
	const infraStructure = [
		{
			id: 'build',
			title: 'Build Infrastructure',
			subtitle: 'Enterprise Orchestration',
			description: 'Multi-tenant workspaces with real-time collaboration, Git integration, and team permissions.',
			icon: Building,
			color: 'from-blue-500 to-cyan-500',
			accent: 'blue',
			features: [
				{ icon: Users, text: 'Team Collaboration' },
				{ icon: GitBranch, text: 'Git Integration' },
				{ icon: Shield, text: 'Access Control' },
				{ icon: Globe, text: 'Multi-tenant' }
			],
			size: 'large'
		},
		{
			id: 'lang',
			title: 'Language Runtime',
			subtitle: 'Universal Execution',
			description: 'Python, R, JavaScript, SQL—all running in secure sandboxed environments.',
			icon: Code,
			color: 'from-green-500 to-emerald-500',
			accent: 'green',
			features: [
				{ icon: Terminal, text: 'Multi-language' },
				{ icon: Cpu, text: 'Sandboxed' },
				{ icon: Zap, text: 'Live execution' }
			],
			size: 'medium'
		},
		{
			id: 'proc',
			title: 'AI Processing',
			subtitle: 'Intelligent Assistance',
			description: 'Context-aware AI that understands your workspace and generates intelligent suggestions.',
			icon: Brain,
			color: 'from-purple-500 to-pink-500',
			accent: 'purple',
			features: [
				{ icon: Sparkles, text: 'Context-aware' },
				{ icon: FileText, text: 'Auto-docs' },
				{ icon: BarChart3, text: 'Insights' }
			],
			size: 'medium'
		},
		{
			id: 'store',
			title: 'Storage Engine',
			subtitle: 'Infinite Scale',
			description: 'Hybrid storage with S3, local disk, or cloud—handling everything from code to datasets.',
			icon: Database,
			color: 'from-orange-500 to-red-500',
			accent: 'orange',
			features: [
				{ icon: Cloud, text: 'Hybrid storage' },
				{ icon: GitBranch, text: 'Versioned' },
				{ icon: Shield, text: 'Secure' }
			],
			size: 'large'
		}
	];
	
	onMount(() => {
		mounted = true;
	});
</script>

<section class="py-16 sm:py-24">
	<div class="container max-w-7xl">
		<!-- Section Header -->
		<div class="text-center mb-16">
			<Badge variant="secondary" class="mb-4 px-4 py-2 text-sm font-medium bg-slate-50 text-slate-700 border-slate-200">
				<Building class="w-4 h-4 mr-2" />
				Four Layers of Infrastructure
			</Badge>
			<h2 class="text-4xl sm:text-5xl lg:text-6xl font-bold text-slate-900 mb-6">
				What's
				<span class="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
					Backing You Up
				</span>
			</h2>
			<p class="text-xl text-slate-600 max-w-3xl mx-auto leading-relaxed">
				Every keystroke, every collaboration, every insight—powered by enterprise-grade infrastructure 
				designed to scale from your first document to your thousandth team member.
			</p>
		</div>

		<!-- Bento Grid -->
		<div class="grid grid-cols-1 lg:grid-cols-4 gap-4 sm:gap-6">
			{#each infraStructure as layer}
				<Card 
					class={cn(
						"group relative overflow-hidden transition-all duration-500 hover:shadow-2xl hover:-translate-y-2 cursor-pointer",
						layer.size === 'large' ? 'lg:col-span-2 lg:row-span-2' : 'lg:col-span-1',
						hoveredCard === layer.id ? 'ring-2 ring-offset-2' : '',
						layer.accent === 'blue' && hoveredCard === layer.id ? 'ring-blue-500' : '',
						layer.accent === 'green' && hoveredCard === layer.id ? 'ring-green-500' : '',
						layer.accent === 'purple' && hoveredCard === layer.id ? 'ring-purple-500' : '',
						layer.accent === 'orange' && hoveredCard === layer.id ? 'ring-orange-500' : ''
					)}
					onmouseenter={() => hoveredCard = layer.id}
					onmouseleave={() => hoveredCard = null}
				>
					<!-- Background Gradient -->
					<div class={cn(
						"absolute inset-0 bg-gradient-to-br opacity-5 group-hover:opacity-10 transition-opacity duration-500",
						layer.color
					)}></div>
					
					<!-- Floating Particles Effect -->
					<div class="absolute inset-0 overflow-hidden">
						{#if mounted}
							{#each Array(6) as _, i}
								<div 
									class={cn(
										"absolute w-1 h-1 rounded-full opacity-20 animate-pulse",
										layer.accent === 'blue' ? 'bg-blue-400' : '',
										layer.accent === 'green' ? 'bg-green-400' : '',
										layer.accent === 'purple' ? 'bg-purple-400' : '',
										layer.accent === 'orange' ? 'bg-orange-400' : ''
									)}
									style="left: {Math.random() * 100}%; top: {Math.random() * 100}%; animation-delay: {i * 0.5}s;"
								></div>
							{/each}
						{/if}
					</div>

					<CardContent class={cn(
						"p-6 sm:p-8 h-full flex flex-col relative z-10",
						layer.size === 'large' ? 'justify-between' : 'justify-start'
					)}>
						<!-- Header -->
						<div class="mb-6">
							<div class="flex items-center space-x-4 mb-4">
								<div class={cn(
									"w-12 h-12 sm:w-16 sm:h-16 rounded-2xl bg-gradient-to-r flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform duration-500",
									layer.color
								)}>
									{#if layer.icon}
										{@const IconComponent = layer.icon}
										<IconComponent class="w-6 h-6 sm:w-8 sm:h-8 text-white" />
									{/if}
								</div>
								<div>
									<Badge variant="outline" class="text-xs mb-2 border-slate-200">
										{layer.subtitle}
									</Badge>
									<h3 class="text-xl sm:text-2xl font-bold text-slate-900">{layer.title}</h3>
								</div>
							</div>
							
							<p class="text-slate-600 leading-relaxed">
								{layer.description}
							</p>
						</div>

						<!-- Features Grid -->
						<div class={cn(
							"grid gap-3 mb-6",
							layer.size === 'large' ? 'grid-cols-2' : 'grid-cols-1'
						)}>
							{#each layer.features as feature}
								<div class="flex items-center space-x-3 bg-white/50 rounded-lg p-3 border border-slate-100 group-hover:bg-white/80 transition-colors duration-300">
									<div class={cn(
										"w-6 h-6 rounded bg-gradient-to-r flex items-center justify-center flex-shrink-0",
										layer.color
									)}>
										{#if feature.icon}
											{@const FeatureIcon = feature.icon}
											<FeatureIcon class="w-3 h-3 text-white" />
										{/if}
									</div>
									<span class="text-sm font-medium text-slate-700">{feature.text}</span>
								</div>
							{/each}
						</div>

						<!-- Action Button -->
						{#if layer.size === 'large'}
							<Button 
								variant="ghost" 
								class="group/btn self-start mt-auto text-slate-600 hover:text-slate-900 p-0 h-auto font-medium"
							>
								Learn more about {layer.title}
								<ArrowRight class="ml-2 w-4 h-4 group-hover/btn:translate-x-1 transition-transform duration-200" />
							</Button>
						{/if}
					</CardContent>
				</Card>
			{/each}
		</div>

		<!-- Real-World Scenario -->
		<div class="mt-16 sm:mt-24">
			<div class="bg-slate-900 rounded-3xl p-8 sm:p-12 text-white relative overflow-hidden">
				<!-- Background Effects -->
				<div class="absolute inset-0 bg-gradient-to-r from-blue-900/20 to-purple-900/20 rounded-3xl"></div>
				<div class="absolute top-0 right-0 w-64 h-64 bg-gradient-to-br from-cyan-500/10 to-blue-500/10 rounded-full blur-3xl"></div>
				
				<div class="relative z-10 text-center">
					<h3 class="text-3xl sm:text-4xl font-bold mb-4">
						When You Share With Your Team...
					</h3>
					<p class="text-xl text-slate-300 mb-8 max-w-2xl mx-auto">
						Here's what happens across all four infrastructure layers simultaneously
					</p>
					
					<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
						<div class="bg-white/10 rounded-xl p-4 sm:p-6 backdrop-blur-sm border border-white/10">
							<Building class="w-8 h-8 text-blue-400 mx-auto mb-3" />
							<h4 class="font-semibold mb-2 text-white">Build Layer</h4>
							<p class="text-sm text-slate-300">Permissions managed, workspace synced</p>
						</div>
						<div class="bg-white/10 rounded-xl p-4 sm:p-6 backdrop-blur-sm border border-white/10">
							<Code class="w-8 h-8 text-green-400 mx-auto mb-3" />
							<h4 class="font-semibold mb-2 text-white">Lang Layer</h4>
							<p class="text-sm text-slate-300">Code executes fresh for reproducibility</p>
						</div>
						<div class="bg-white/10 rounded-xl p-4 sm:p-6 backdrop-blur-sm border border-white/10">
							<Brain class="w-8 h-8 text-purple-400 mx-auto mb-3" />
							<h4 class="font-semibold mb-2 text-white">Proc Layer</h4>
							<p class="text-sm text-slate-300">AI provides context for new teammates</p>
						</div>
						<div class="bg-white/10 rounded-xl p-4 sm:p-6 backdrop-blur-sm border border-white/10">
							<Database class="w-8 h-8 text-orange-400 mx-auto mb-3" />
							<h4 class="font-semibold mb-2 text-white">Store Layer</h4>
							<p class="text-sm text-slate-300">Assets versioned and always available</p>
						</div>
					</div>
					
					<Button class="mt-8 bg-white text-slate-900 hover:bg-slate-100 font-semibold">
						See It in Action
						<ArrowRight class="ml-2 w-4 h-4" />
					</Button>
				</div>
			</div>
		</div>
	</div>
</section>