// Test file to verify VFSShare import works
import('./svelte/lib/components/VFSShare.svelte')
  .then(() => {
    console.log('✅ VFSShare.svelte imports successfully');
  })
  .catch((error) => {
    console.error('❌ VFSShare.svelte import failed:', error);
  });

// Test storage API import
import('./svelte/lib/api/storage.ts')
  .then(() => {
    console.log('✅ storage.ts imports successfully');
  })
  .catch((error) => {
    console.error('❌ storage.ts import failed:', error);
  });

// Test client import  
import('./svelte/lib/api/client.ts')
  .then(() => {
    console.log('✅ client.ts imports successfully');
  })
  .catch((error) => {
    console.error('❌ client.ts import failed:', error);
  });

console.log('Testing VFSShare component imports...');