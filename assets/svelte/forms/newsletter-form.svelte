<script lang="ts">
	import { Input } from '$lib/ui/input';
	import { toast } from 'svelte-sonner';
	import { Label } from '$lib/ui/label';
	import { Button } from '$lib/ui/button';

	// Props for LiveView integration
	interface Props {
		live?: any;
	}

	let { live = null }: Props = $props();

	let email = $state('');
	let isLoading = $state(false);

	function handleSubmit(event: Event) {
		event.preventDefault();
		
		if (!email || !email.includes('@')) {
			toast.error('Please enter a valid email address');
			return;
		}

		isLoading = true;

		// If LiveView is available, push event to server
		if (live) {
			live.pushEvent('newsletter_subscribe', { email }, (response: any) => {
				isLoading = false;
				if (response.success) {
					toast.success('Subscribed to newsletter', {
						description: 'You will receive an email shortly.'
					});
					email = ''; // Clear form on success
				} else {
					toast.error('Subscription failed', {
						description: response.error || 'Please try again later.'
					});
				}
			});
		} else {
			// Fallback for client-side only (simulate success)
			setTimeout(() => {
				isLoading = false;
				toast.success('Subscribed to newsletter', {
					description: 'You will receive an email shortly.'
				});
				email = '';
			}, 1000);
		}
	}
</script>

<form class="w-full max-w-sm mx-auto space-y-3 text-center" onsubmit={handleSubmit}>
	<Label for="newsletter-email" class="text-white font-medium">Subscribe to our newsletter</Label>
	<Input 
		id="newsletter-email"
		type="email" 
		class="rounded-full px-4 text-center" 
		placeholder="Enter your email"
		bind:value={email}
		disabled={isLoading}
		required
	/>
	<Button 
		type="submit" 
		size="sm" 
		class="rounded-full px-6 mx-auto"
		disabled={isLoading || !email}
		loading={isLoading}
	>
		{isLoading ? 'Subscribing...' : 'Subscribe'}
	</Button>
</form>