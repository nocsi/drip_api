<script lang="ts">
	import { Label } from '$lib/ui/label';
	import { Input } from '$lib/ui/input';
	import { Button } from '$lib/ui/button';
	import { Icons } from '$lib/shared/icons';
</script>

<div class="grid gap-6">
	<form>
		<div class="grid gap-2">
			<div class="gap-1 grid">
				<Label class="sr-only">Email</Label>
				<Input id="email" placeholder="name@example.com" type="email" />
			</div>
			<Button href="/auth/sign_in">Sign In With Email</Button>
		</div>
	</form>
	<div class="relative">
		<div class="absolute inset-0 flex items-center">
			<span class="w-full border-t"></span>
		</div>
		<div class="relative flex justify-center text-xs uppercase">
			<span class="bg-background px-2 text-muted-foreground"> Or continue with </span>
		</div>
	</div>
	<div class="grid gap-3">
		<Button variant="outline" href="/auth/google">
			<Icons.google class="mr-2 size-4" /> Continue with Google
		</Button>
		<Button variant="outline" href="/auth/github">
			<Icons.gitHub class="mr-2 size-4" /> Continue with GitHub
		</Button>
	</div>
</div>
