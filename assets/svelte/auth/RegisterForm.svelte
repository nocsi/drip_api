<script lang="ts">
	import { Button } from '$lib/ui/button';
	import { Input } from '$lib/ui/input';
	import { Label } from '$lib/ui/label';
	import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '$lib/ui/card';
	import { Separator } from '$lib/ui/separator';
	import { Checkbox } from '$lib/ui/checkbox';
	import { Eye, EyeOff, Mail, Lock, User, Loader2, Check } from '@lucide/svelte';

	// Props for LiveView integration
	interface Props {
		redirectTo?: string;
		showSignIn?: boolean;
	}

	let { redirectTo = "/home", showSignIn = true }: Props = $props();

	// Form state
	let email = $state('');
	let password = $state('');
	let passwordConfirmation = $state('');
	let showPassword = $state(false);
	let showPasswordConfirmation = $state(false);
	let acceptTerms = $state(false);

	// Password strength indicators
	let passwordStrength = $derived(() => {
		const checks = {
			length: password.length >= 8,
			lowercase: /[a-z]/.test(password),
			uppercase: /[A-Z]/.test(password),
			number: /\d/.test(password),
			special: /[^A-Za-z0-9]/.test(password)
		};
		
		const score = Object.values(checks).filter(Boolean).length;
		return { checks, score };
	});

	// Toggle password visibility
	function togglePasswordVisibility() {
		showPassword = !showPassword;
	}

	function togglePasswordConfirmationVisibility() {
		showPasswordConfirmation = !showPasswordConfirmation;
	}

	// Handle OAuth sign up
	function handleOAuthSignUp(provider: 'apple' | 'google') {
		window.location.href = `/auth/${provider}?redirect_to=${encodeURIComponent(redirectTo)}`;
	}

	// Get password strength color
	function getStrengthColor(score: number): string {
		if (score <= 2) return 'bg-red-500';
		if (score <= 3) return 'bg-yellow-500';
		return 'bg-green-500';
	}

	function getStrengthText(score: number): string {
		if (score <= 2) return 'Weak';
		if (score <= 3) return 'Good';
		return 'Strong';
	}
</script>

<Card class="w-full max-w-md mx-auto">
	<CardHeader class="text-center">
		<div class="flex items-center justify-center mb-4">
			<div class="w-12 h-12 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
				<span class="text-white font-bold text-lg">K</span>
			</div>
		</div>
		<CardTitle class="text-2xl font-bold">Create your account</CardTitle>
		<CardDescription>
			Join Kyozo and start creating executable documents
		</CardDescription>
	</CardHeader>

	<CardContent class="space-y-4">
		<!-- OAuth Sign Up -->
		<div class="space-y-2">
			<Button 
				variant="outline" 
				class="w-full" 
				onclick={() => handleOAuthSignUp('apple')}
			>
				<svg class="w-5 h-5 mr-2" viewBox="0 0 24 24" fill="currentColor">
					<path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 5.079 3.158 9.417 7.618 11.024-.105-.949-.199-2.403.041-3.439.219-.937 1.404-5.965 1.404-5.965s-.359-.72-.359-1.781c0-1.663.967-2.911 2.168-2.911 1.024 0 1.518.769 1.518 1.688 0 1.029-.653 2.567-.992 3.992-.285 1.193.6 2.165 1.775 2.165 2.128 0 3.768-2.245 3.768-5.487 0-2.861-2.063-4.869-5.008-4.869-3.41 0-5.409 2.562-5.409 5.199 0 1.033.394 2.143.889 2.741.099.12.112.225.085.347-.09.375-.294 1.198-.334 1.363-.053.225-.172.271-.402.165-1.495-.69-2.433-2.878-2.433-4.646 0-3.776 2.748-7.252 7.92-7.252 4.158 0 7.392 2.967 7.392 6.923 0 4.135-2.607 7.462-6.233 7.462-1.214 0-2.357-.629-2.748-1.378l-.748 2.853c-.271 1.043-1.002 2.35-1.492 3.146C9.57 23.812 10.763 24.009 12.017 24.009c6.624 0 11.99-5.367 11.99-11.988C24.007 5.367 18.641.001.001 12.017.001z"/>
				</svg>
				Continue with Apple
			</Button>
		</div>

		<Separator class="my-4" />

		<!-- Email/Password Registration Form -->
		<form phx-submit="register_with_password" class="space-y-4">
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
						placeholder="Create a password"
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

				<!-- Password Strength Indicator -->
				{#if password}
					<div class="space-y-2">
						<div class="flex items-center space-x-2">
							<div class="flex-1 bg-gray-200 rounded-full h-2">
								<div 
									class="h-2 rounded-full transition-all duration-300 {getStrengthColor(passwordStrength.score)}"
									style="width: {(passwordStrength.score / 5) * 100}%"
								></div>
							</div>
							<span class="text-xs text-gray-600">{getStrengthText(passwordStrength.score)}</span>
						</div>
						<div class="grid grid-cols-2 gap-1 text-xs">
							<div class="flex items-center space-x-1">
								{#if passwordStrength.checks.length}
									<Check class="w-3 h-3 text-green-500" />
								{:else}
									<div class="w-3 h-3 border border-gray-300 rounded-full"></div>
								{/if}
								<span class={passwordStrength.checks.length ? 'text-green-600' : 'text-gray-500'}>8+ chars</span>
							</div>
							<div class="flex items-center space-x-1">
								{#if passwordStrength.checks.number}
									<Check class="w-3 h-3 text-green-500" />
								{:else}
									<div class="w-3 h-3 border border-gray-300 rounded-full"></div>
								{/if}
								<span class={passwordStrength.checks.number ? 'text-green-600' : 'text-gray-500'}>Number</span>
							</div>
							<div class="flex items-center space-x-1">
								{#if passwordStrength.checks.uppercase}
									<Check class="w-3 h-3 text-green-500" />
								{:else}
									<div class="w-3 h-3 border border-gray-300 rounded-full"></div>
								{/if}
								<span class={passwordStrength.checks.uppercase ? 'text-green-600' : 'text-gray-500'}>Uppercase</span>
							</div>
							<div class="flex items-center space-x-1">
								{#if passwordStrength.checks.special}
									<Check class="w-3 h-3 text-green-500" />
								{:else}
									<div class="w-3 h-3 border border-gray-300 rounded-full"></div>
								{/if}
								<span class={passwordStrength.checks.special ? 'text-green-600' : 'text-gray-500'}>Special</span>
							</div>
						</div>
					</div>
				{/if}


			</div>

			<!-- Password Confirmation Field -->
			<div class="space-y-2">
				<Label for="password_confirmation">Confirm Password</Label>
				<div class="relative">
					<Lock class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
					<Input
						id="password_confirmation"
						name="password_confirmation"
						type={showPasswordConfirmation ? 'text' : 'password'}
						placeholder="Confirm your password"
						bind:value={passwordConfirmation}
						class="pl-10 pr-10"
						required
					/>
					<button
						type="button"  
						onclick={togglePasswordConfirmationVisibility}
						class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
					>
						{#if showPasswordConfirmation}
							<EyeOff class="w-4 h-4" />
						{:else}
							<Eye class="w-4 h-4" />
						{/if}
					</button>
				</div>

			</div>

			<!-- Terms and Conditions -->
			<div class="flex items-center space-x-2">
				<Checkbox 
					id="terms" 
					name="accept_terms"
					bind:checked={acceptTerms}
				/>
				<Label for="terms" class="text-sm leading-none">
					I agree to the 
					<a href="/terms" class="text-blue-600 hover:text-blue-500 underline" target="_blank">
						Terms of Service
					</a>
					and 
					<a href="/privacy" class="text-blue-600 hover:text-blue-500 underline" target="_blank">
						Privacy Policy
					</a>
				</Label>
			</div>


			<!-- Sign Up Button -->
			<Button type="submit" class="w-full">
				<User class="w-4 h-4 mr-2" />
				Create account
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
				Sign up with magic link instead
			</Button>
		</form>
	</CardContent>

	{#if showSignIn}
		<CardFooter class="text-center">
			<p class="text-sm text-gray-600">
				Already have an account?
				<a href="/auth/sign_in" class="text-blue-600 hover:text-blue-500 font-medium">
					Sign in
				</a>
			</p>
		</CardFooter>
	{/if}
</Card>