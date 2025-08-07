<script lang="ts">
  import HeroLanding from './sections/HeroLanding.svelte';
  import Powered from './sections/Powered.svelte';
  import PreviewLanding from './sections/PreviewLanding.svelte';
</script>

<div class="flex min-h-screen flex-col">
  <HeroLanding></HeroLanding>
  <Powered />
  <PreviewLanding />
  <!-- <BentoGrid /> -->
  <!-- <InfoLanding data={infos[0]} reverse={true} /> -->

</div>
