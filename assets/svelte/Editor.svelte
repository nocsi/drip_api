<script lang="ts">
	import type { Content, Editor } from '@tiptap/core';
	import { ShadcnEditor, ShadcnToolBar, ShadcnDragHandle, ShadcnBubbleMenu } from 'elim';
	import type { Transaction } from '@tiptap/pm/state';
	import { AiAgent, AiAgentPopover } from 'elim';
	import { onMount, onDestroy, createEventDispatcher } from 'svelte';

	// Props that can be passed from LiveView or parent components
	interface Props {
		initialContent?: Content;
		editable?: boolean;
		placeholder?: string;
		className?: string;
	}

	let {
		initialContent = {},
		editable = true,
		placeholder = "Start writing...",
		className = ""
	}: Props = $props();

	// Event dispatcher for parent components
	const dispatch = createEventDispatcher();

	// Editor state
	let content = $state<Content>(initialContent);
	let editor: Editor | undefined = $state<Editor>();
	let showToolBar = $state(true);
	let showSlashCommands = $state(true);
	let showLinkBubbleMenu = $state(true);
	let showTableBubbleMenu = $state(true);

	// Editor event handlers
	function onUpdate({ editor: updatedEditor, transaction }: { editor: Editor, transaction: Transaction }) {
		if (!updatedEditor) return;

		content = updatedEditor.getJSON();

		// Get markdown content for notebook integration
		const markdownContent = updatedEditor.storage.markdown?.getMarkdown?.() || updatedEditor.getText();

		// Store content in localStorage for persistence
		localStorage.setItem('tiptap-content', JSON.stringify(content));

		// Dispatch content change event for parent components (like notebook)
		dispatch('contentChange', markdownContent);

		console.log('Editor content updated:', content);
	}

	function onFileUpload(file: File) {
		console.log('File uploaded:', file);

		// Handle file upload
		const reader = new FileReader();
		reader.onload = (e) => {
			const result = e.target?.result;

			console.log('File uploaded:', {
				fileName: file.name,
				fileSize: file.size,
				fileType: file.type,
				dataUrl: result
			});
		};
		reader.readAsDataURL(file);
	}

	function onAIAutoComplete(prompt: string, context?: any) {
		console.log('AI auto complete requested:', prompt);

		console.log('AI completion requested:', {
			prompt,
			context,
			selection: editor ? {
				from: editor.state.selection.from,
				to: editor.state.selection.to,
				text: editor.state.doc.textBetween(
					editor.state.selection.from,
					editor.state.selection.to
				)
			} : null
		});
	}

	function onFocus() {
		console.log('Editor focused');
	}

	function onBlur() {
		console.log('Editor blurred');
	}

	// Watch for content changes from parent components
	$effect(() => {
		if (editor && initialContent && typeof initialContent === 'string') {
			// Handle markdown content from notebook
			const currentContent = editor.storage.markdown?.getMarkdown?.() || editor.getText();
			if (initialContent !== currentContent) {
				console.log('Setting content from parent:', initialContent);
				editor.commands.setContent(initialContent);
			}
		} else if (editor && initialContent && typeof initialContent === 'object') {
			// Handle JSON content
			const currentContent = JSON.stringify(editor.getJSON());
			if (JSON.stringify(initialContent) !== currentContent) {
				console.log('Setting JSON content from parent:', initialContent);
				editor.commands.setContent(initialContent);
			}
		}
	});

	// Watch for editable changes from LiveView
	$effect(() => {
		if (editor && editor.isEditable !== editable) {
			console.log('Setting editable:', editable);
			editor.setEditable(editable);
		}
	});

	onMount(() => {
		console.log('Editor component mounted');
	});

	onDestroy(() => {
		console.log('Editor component destroyed');
	});
</script>

<!-- The LiveViewTiptapHook should be attached to this div -->
<div class="tiptap-editor-container {className}" id="tiptap-editor-hook" phx-hook="LiveViewTiptapHook">
	<div class="w-7xl mx-auto grid grid-cols-3 px-6 py-4">
		<div class="col-start-2 text-center text-xl font-bold">LiveView TipTap Editor</div>
		<div class="text-right">
			<a class="text-sm text-muted-foreground hover:underline" href="/examples/headless">
				View headless example
			</a>
		</div>
	</div>

	<div class="w-7xl mx-auto px-4">
		{#if editor && showToolBar}
			<div class="rounded-t border-x border-t p-1">
				<!-- Default Editor toolbar -->
				<ShadcnToolBar {editor} />

				<!-- Customized Editor toolbar with LiveView integration -->
				<ShadcnToolBar {editor}>
					<div class="border-r px-3 text-sm">LiveView Connected</div>
					<div class="flex items-center space-x-2 px-3">
						<div class="w-2 h-2 bg-green-500 rounded-full"></div>
						<span class="text-xs">Real-time</span>
					</div>
				</ShadcnToolBar>
			</div>
			<!-- Add bubble menu -->
			<ShadcnBubbleMenu {editor} />
			<ShadcnDragHandle {editor} />
		{/if}

		<div class="rounded-b border">
			<ShadcnEditor
			class="h-[30rem] max-h-screen overflow-y-scroll pr-2 pl-6"
				bind:editor
				onFileUpload={onFileUpload}
				onAIAutoComplete={onAIAutoComplete}
				{content}
				{showSlashCommands}
				{showLinkBubbleMenu}
				{showTableBubbleMenu}
				onUpdate={onUpdate}
				onFocus={onFocus}
				onBlur={onBlur}
				{editable}
				{placeholder}
			/>

			{#if editor && editor.storage.aiAgent?.thoughts?.length}
				<AiAgentPopover
					{editor}
					thoughts={editor.storage.aiAgent.thoughts}
					toolResults={editor.storage.aiAgent.toolResults}
					finalSuggestion={editor.storage.aiAgent.finalSuggestion}
					plan={editor.storage.aiAgent.plan}
					isStreaming={editor.storage.aiAgent.isStreaming}
				/>
			{/if}
		</div>

		<!-- LiveView Integration Status -->
		<div class="mt-4 p-2 bg-gray-50 rounded text-sm text-gray-600">
			<div class="flex items-center justify-between">
				<span>Editor Status: {editor ? 'Ready' : 'Loading...'}</span>
				<span>Editable: {editable ? 'Yes' : 'No'}</span>
			</div>
		</div>
	</div>
</div>
