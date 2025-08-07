<script>
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '$lib/ui/card';
  import { Button } from '$lib/ui/button';
  import { Badge } from '$lib/ui/badge';
  import {
    Check,
    Star,
    Users,
    Building2,
    Rocket,
    ArrowRight,
    Crown
  } from '@lucide/svelte';

  const plans = [
    {
      name: "Personal",
      description: "Perfect for individual developers and researchers",
      price: "Free",
      period: "forever",
      icon: Users,
      popular: false,
      features: [
        "Up to 10 executable documents",
        "Python, JavaScript, and R support",
        "Basic export (HTML, PDF)",
        "Community support",
        "1GB storage",
        "Standard execution time"
      ],
      cta: "Get started",
      variant: "outline"
    },
    {
      name: "Pro",
      description: "Advanced features for professional developers",
      price: "$19",
      period: "per month",
      icon: Star,
      popular: true,
      features: [
        "Unlimited documents",
        "All language support (SQL, Shell, etc.)",
        "Advanced export options",
        "Priority support",
        "10GB storage",
        "Fast execution priority",
        "Custom themes & styling",
        "API access",
        "Collaboration features"
      ],
      cta: "Start free trial",
      variant: "default"
    },
    {
      name: "Team",
      description: "Collaboration tools for teams and organizations",
      price: "$49",
      period: "per user/month",
      icon: Building2,
      popular: false,
      features: [
        "Everything in Pro",
        "Team workspaces",
        "Real-time collaboration",
        "Admin controls & permissions",
        "100GB shared storage",
        "Enterprise integrations",
        "Custom branding",
        "Advanced analytics",
        "SSO support"
      ],
      cta: "Contact sales",
      variant: "outline"
    }
  ];

  function handlePlanSelect(planName) {
    console.log(`Selected plan: ${planName}`);
    // Handle plan selection
  }

  function handleContactUs() {
    console.log('Contact us clicked');
    // Handle contact action
  }

  function handleViewFAQ() {
    console.log('View FAQ clicked');
    // Handle FAQ action
  }

  function handleTalkToSales() {
    console.log('Talk to sales clicked');
    // Handle sales contact
  }
</script>

<section class="py-24 bg-muted/30">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <!-- Header -->
    <div class="text-center mb-16">
      <Badge variant="outline" class="mb-4">Pricing</Badge>
      <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
        Simple, transparent pricing
      </h2>
      <p class="mt-4 text-lg text-muted-foreground max-w-2xl mx-auto">
        Choose the plan that's right for you. Start free and upgrade as you grow.
      </p>
    </div>

    <!-- Pricing Cards -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-16">
      {#each plans as plan}
        <Card class={`relative border-0 shadow-sm hover:shadow-md transition-all duration-200 ${plan.popular ? 'ring-2 ring-primary shadow-lg scale-105' : ''}`}>
          {#if plan.popular}
            <div class="absolute -top-4 left-1/2 transform -translate-x-1/2">
              <Badge class="bg-primary text-primary-foreground px-4 py-1">
                <Crown class="w-3 h-3 mr-1" />
                Most Popular
              </Badge>
            </div>
          {/if}

          <CardHeader class="text-center pb-8">
            <div class="mx-auto w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-6">
              <plan.icon class="w-8 h-8 text-primary" />
            </div>
            <CardTitle class="text-2xl">{plan.name}</CardTitle>
            <CardDescription class="text-base">{plan.description}</CardDescription>

            <div class="mt-6">
              <div class="flex items-baseline justify-center">
                <span class="text-4xl font-bold tracking-tight">{plan.price}</span>
                {#if plan.period !== 'forever'}
                  <span class="text-muted-foreground ml-1">/{plan.period}</span>
                {/if}
              </div>
              {#if plan.period === 'forever'}
                <p class="text-sm text-muted-foreground mt-1">No credit card required</p>
              {:else if plan.name === 'Pro'}
                <p class="text-sm text-muted-foreground mt-1">14-day free trial</p>
              {/if}
            </div>
          </CardHeader>

          <CardContent class="pt-0">
            <Button
              class="w-full mb-8"
              variant={plan.variant}
              size="lg"
              onclick={() => handlePlanSelect(plan.name)}
            >
              {plan.cta}
              <ArrowRight class="ml-2 h-4 w-4" />
            </Button>

            <ul class="space-y-3">
              {#each plan.features as feature}
                <li class="flex items-start">
                  <Check class="w-5 h-5 text-green-500 mr-3 mt-0.5 flex-shrink-0"
 />
                  <span class="text-sm text-muted-foreground">{feature}</span>
                </li>
              {/each}
            </ul>
          </CardContent>
        </Card>
      {/each}
    </div>

    <!-- Enterprise Section -->
    <Card class="border-0 shadow-sm bg-gradient-to-r from-primary/5 to-primary/10">
      <CardContent class="p-8">
        <div class="flex flex-col lg:flex-row items-center justify-between gap-6">
          <div class="text-center lg:text-left">
            <div class="flex items-center justify-center lg:justify-start mb-4">
              <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center mr-4">
                <Rocket class="w-6 h-6 text-primary" />
              </div>
              <h3 class="text-2xl font-bold">Enterprise</h3>
            </div>
            <p class="text-muted-foreground mb-2">
              Custom solutions for large organizations with specific requirements
            </p>
            <div class="flex flex-wrap justify-center lg:justify-start gap-2 text-sm text-muted-foreground">
              <span>• Custom deployment</span>
              <span>• Dedicated support</span>
              <span>• SLA guarantees</span>
              <span>• Training & onboarding</span>
            </div>
          </div>
          <div class="flex-shrink-0">
            <Button size="lg" variant="outline" class="px-8" onclick={handleContactUs}>
              Contact us
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>

    <!-- FAQ Preview -->
    <div class="mt-20 text-center">
      <h3 class="text-xl font-semibold mb-4">Questions about pricing?</h3>
      <p class="text-muted-foreground mb-6">
        We're here to help. Check out our FAQ or get in touch with our team.
      </p>
      <div class="flex flex-col sm:flex-row gap-4 justify-center">
        <Button variant="outline" onclick={handleViewFAQ}>
          View FAQ
        </Button>
        <Button variant="ghost" onclick={handleTalkToSales}>
          Talk to sales
        </Button>
      </div>
    </div>

    <!-- Money Back Guarantee -->
    <div class="mt-16 text-center">
      <div class="inline-flex items-center px-6 py-3 rounded-full bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-400">
        <Check class="w-5 h-5 mr-2" />
        <span class="text-sm font-medium">30-day money-back guarantee on all paid plans</span>
      </div>
    </div>
  </div>
</section>