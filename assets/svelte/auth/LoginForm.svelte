<script lang="ts">
	import { Button } from '$lib/ui/button';
	import { Input } from '$lib/ui/input';
	import { Label } from '$lib/ui/label';
	import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '$lib/ui/card';
	import { Separator } from '$lib/ui/separator';
	import { Eye, EyeOff, Mail, Lock, Loader2 } from '@lucide/svelte';

	// Props for LiveView integration
	interface Props {
		redirectTo?: string;
		showSignUp?: boolean;
	}

	let { redirectTo = "/home", showSignUp = true }: Props = $props();

	// Form state
	let email = $state('');
	let password = $state('');
	let showPassword = $state(false);
	let errors = $state<{email?: string; password?: string; general?: string}>({});

	// Toggle password visibility
	function togglePasswordVisibility() {
		showPassword = !showPassword;
	}

	// Handle OAuth sign in
	function handleOAuthSignIn(provider: 'apple' | 'google') {
		window.location.href = `/auth/${provider}?redirect_to=${encodeURIComponent(redirectTo)}`;
	}
</script>

<Card class="w-full max-w-md mx-auto">
	<CardHeader class="text-center">
		<div class="flex items-center justify-center mb-4">
			<div class="w-12 h-12 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
				<span class="text-white font-bold text-lg">K</span>
			</div>
		</div>
		<CardTitle class="text-2xl font-bold">Welcome back</CardTitle>
		<CardDescription>
			Sign in to your Kyozo account
		</CardDescription>
	</CardHeader>

	<CardContent class="space-y-4">
		<!-- OAuth Sign In -->
		<div class="space-y-2">
			<Button 
				variant="outline" 
				class="w-full" 
				onclick={() => handleOAuthSignIn('apple')}
			>
				<svg class="w-5 h-5 mr-2" viewBox="0 0 24 24" fill="currentColor">
					<path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 5.079 3.158 9.417 7.618 11.024-.105-.949-.199-2.403.041-3.439.219-.937 1.404-5.965 1.404-5.965s-.359-.72-.359-1.781c0-1.663.967-2.911 2.168-2.911 1.024 0 1.518.769 1.518 1.688 0 1.029-.653 2.567-.992 3.992-.285 1.193.6 2.165 1.775 2.165 2.128 0 3.768-2.245 3.768-5.487 0-2.861-2.063-4.869-5.008-4.869-3.41 0-5.409 2.562-5.409 5.199 0 1.033.394 2.143.889 2.741.099.12.112.225.085.347-.09.375-.294 1.198-.334 1.363-.053.225-.172.271-.402.165-1.495-.69-2.433-2.878-2.433-4.646 0-3.776 2.748-7.252 7.92-7.252 4.158 0 7.392 2.967 7.392 6.923 0 4.135-2.607 7.462-6.233 7.462-1.214 0-2.357-.629-2.748-1.378l-.748 2.853c-.271 1.043-1.002 2.35-1.492 3.146C9.57 23.812 10.763 24.009 12.017 24.009c6.624 0 11.99-5.367 11.99-11.988C24.007 5.367 18.641.001.001 12.017.001z"/>
				</svg>
				Continue with Apple
			</Button>
		</div>

		<Separator class="my-4" />

		<!-- Email/Password Form -->
		<form phx-submit="sign_in_with_password" class="space-y-4">
			<input type="hidden" name="redirect_to" value={redirectTo} />
			
			<!-- Email Field -->
			<div class="space-y-2">
				<Label for="email">Email</Label>
				<div class="relative">
					<Mail class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
					<Input
						id="email"
						name="email"
						type="email"
						placeholder="Enter your email"
						bind:value={email}
						class="pl-10"
						required
					/>
				</div>
			</div>

			<!-- Password Field -->
			<div class="space-y-2">
				<Label for="password">Password</Label>
				<div class="relative">
					<Lock class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
					<Input
						id="password"
						name="password"
						type={showPassword ? 'text' : 'password'}
						placeholder="Enter your password"
						bind:value={password}
						class="pl-10 pr-10"
						required
					/>
					<button
						type="button"
						onclick={togglePasswordVisibility}
						class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
					>
						{#if showPassword}
							<EyeOff class="w-4 h-4" />
						{:else}
							<Eye class="w-4 h-4" />
						{/if}
					</button>
				</div>
			</div>

			<!-- Sign In Button -->
			<Button type="submit" class="w-full">
				Sign in
			</Button>

			<!-- Magic Link Button -->
			<Button 
				type="button" 
				variant="ghost" 
				class="w-full" 
				phx-click="request_magic_link"
				phx-value-email={email}
			>
				<Mail class="w-4 h-4 mr-2" />
				Send magic link instead
			</Button>
		</form>
	</CardContent>

	{#if showSignUp}
		<CardFooter class="text-center">
			<p class="text-sm text-gray-600">
				Don't have an account?
				<a href="/auth/register" class="text-blue-600 hover:text-blue-500 font-medium">
					Sign up
				</a>
			</p>
		</CardFooter>
	{/if}
</Card>