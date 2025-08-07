defmodule Kyozo.Workspaces.Extensions.RenderMarkdown.Calculations.MarkdownStats do
  @moduledoc """
  Calculates statistics about markdown content such as word count, reading time,
  heading count, code block count, and other useful metrics.
  
  This calculation provides insights into the content structure and complexity
  for better content management and user experience.
  """

  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    # We need to load all markdown attributes that might contain content
    # This will be determined by the render_attributes configuration
    []
  end

  @impl true
  def select(_query, _opts, _context) do
    # Return the attributes we need to analyze
    # This should include all source markdown attributes
    []
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Get all markdown content from the record
      markdown_content = extract_markdown_content(record)
      
      case markdown_content do
        nil -> 
          %{
            word_count: 0,
            character_count: 0,
            reading_time_minutes: 0,
            heading_count: 0,
            code_block_count: 0,
            link_count: 0,
            image_count: 0,
            list_count: 0,
            paragraph_count: 0,
            line_count: 0,
            complexity_score: 0,
            estimated_difficulty: :beginner
          }
        
        content when is_binary(content) ->
          calculate_stats(content)
        
        content when is_list(content) ->
          # Handle array of markdown content
          combined_content = Enum.join(content, "\n\n")
          calculate_stats(combined_content)
        
        _ ->
          # Fallback for unexpected content types
          %{
            word_count: 0,
            character_count: 0,
            reading_time_minutes: 0,
            heading_count: 0,
            code_block_count: 0,
            link_count: 0,
            image_count: 0,
            list_count: 0,
            paragraph_count: 0,
            line_count: 0,
            complexity_score: 0,
            estimated_difficulty: :beginner
          }
      end
    end)
  end

  defp extract_markdown_content(record) do
    # Try to find markdown content from common attribute names
    # This is a heuristic approach since we don't have access to the render_attributes config here
    markdown_attrs = [:content, :body, :description, :text, :markdown, :source]
    
    Enum.find_value(markdown_attrs, fn attr ->
      case Map.get(record, attr) do
        nil -> nil
        "" -> nil
        content -> content
      end
    end)
  end

  defp calculate_stats(content) when is_binary(content) do
    lines = String.split(content, "\n")
    line_count = length(lines)
    
    # Remove code blocks for more accurate word/paragraph counting
    content_without_code = remove_code_blocks(content)
    
    # Basic text statistics
    word_count = count_words(content_without_code)
    character_count = String.length(content)
    paragraph_count = count_paragraphs(content_without_code)
    
    # Markdown-specific statistics
    heading_count = count_headings(content)
    code_block_count = count_code_blocks(content)
    link_count = count_links(content)
    image_count = count_images(content)
    list_count = count_lists(content)
    
    # Derived statistics
    reading_time_minutes = calculate_reading_time(word_count)
    complexity_score = calculate_complexity_score(
      word_count, heading_count, code_block_count, 
      link_count, list_count, line_count
    )
    estimated_difficulty = estimate_difficulty(complexity_score, code_block_count, word_count)
    
    %{
      word_count: word_count,
      character_count: character_count,
      reading_time_minutes: reading_time_minutes,
      heading_count: heading_count,
      code_block_count: code_block_count,
      link_count: link_count,
      image_count: image_count,
      list_count: list_count,
      paragraph_count: paragraph_count,
      line_count: line_count,
      complexity_score: complexity_score,
      estimated_difficulty: estimated_difficulty
    }
  end

  defp remove_code_blocks(content) do
    # Remove fenced code blocks (```)
    content
    |> String.replace(~r/```[^`]*```/s, "")
    # Remove inline code (`code`)
    |> String.replace(~r/`[^`]+`/, "")
  end

  defp count_words(content) do
    content
    |> String.replace(~r/[^\w\s]/u, " ")  # Replace non-word chars with spaces
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp count_paragraphs(content) do
    content
    |> String.split(~r/\n\s*\n/, trim: true)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> length()
  end

  defp count_headings(content) do
    Regex.scan(~r/^[#]{1,6}\s+.+$/m, content)
    |> length()
  end

  defp count_code_blocks(content) do
    # Count fenced code blocks
    fenced_blocks = Regex.scan(~r/```[^`]*```/s, content) |> length()
    
    # Count indented code blocks (4+ spaces at start of line)
    indented_blocks = 
      content
      |> String.split("\n")
      |> Enum.chunk_while(
        [],
        fn line, acc ->
          if String.match?(line, ~r/^    \S/) do
            {:cont, [line | acc]}
          else
            if length(acc) > 0 do
              {:cont, Enum.reverse(acc), []}
            else
              {:cont, []}
            end
          end
        end,
        fn acc -> {:cont, Enum.reverse(acc), []} end
      )
      |> Enum.reject(&Enum.empty?/1)
      |> length()
    
    fenced_blocks + indented_blocks
  end

  defp count_links(content) do
    # Count markdown links [text](url) and reference links [text][ref]
    markdown_links = Regex.scan(~r/\[([^\]]+)\]\(([^)]+)\)/, content) |> length()
    reference_links = Regex.scan(~r/\[([^\]]+)\]\[([^\]]*)\]/, content) |> length()
    
    # Count bare URLs
    url_pattern = ~r/https?:\/\/[^\s<>"'\[\]{}|\\^`]+/
    bare_urls = Regex.scan(url_pattern, content) |> length()
    
    markdown_links + reference_links + bare_urls
  end

  defp count_images(content) do
    # Count markdown images ![alt](src) and reference images ![alt][ref]
    markdown_images = Regex.scan(~r/!\[([^\]]*)\]\(([^)]+)\)/, content) |> length()
    reference_images = Regex.scan(~r/!\[([^\]]*)\]\[([^\]]*)\]/, content) |> length()
    markdown_images + reference_images
  end

  defp count_lists(content) do
    lines = String.split(content, "\n")
    
    {_in_list, list_count} = 
      Enum.reduce(lines, {false, 0}, fn line, {in_list, count} ->
        trimmed = String.trim(line)
        
        cond do
          # Unordered list item
          String.match?(trimmed, ~r/^\s*[-*+]\s+/) ->
            if in_list do
              {true, count}
            else
              {true, count + 1}
            end
          
          # Ordered list item
          String.match?(trimmed, ~r/^\s*\d+\.\s+/) ->
            if in_list do
              {true, count}
            else
              {true, count + 1}
            end
          
          # Empty line or non-list content
          String.trim(line) == "" ->
            {in_list, count}
          
          true ->
            {false, count}
        end
      end)
    
    list_count
  end

  defp calculate_reading_time(word_count) do
    # Average reading speed is about 200-250 words per minute
    # We'll use 225 as a middle ground
    average_wpm = 225
    
    (word_count / average_wpm)
    |> Float.ceil()
    |> trunc()
    |> max(1)  # Minimum 1 minute
  end

  defp calculate_complexity_score(word_count, heading_count, code_block_count, link_count, list_count, line_count) do
    # Weighted complexity calculation
    base_score = 0
    
    # Word count contribution (0-40 points)
    word_score = min(word_count / 50, 40)
    
    # Structure complexity (0-30 points)
    structure_score = min((heading_count * 2) + (list_count * 1.5), 30)
    
    # Code complexity (0-20 points)
    code_score = min(code_block_count * 4, 20)
    
    # Link complexity (0-10 points)
    link_score = min(link_count * 0.5, 10)
    
    total_score = base_score + word_score + structure_score + code_score + link_score
    
    # Normalize to 0-100 scale
    min(total_score, 100)
    |> Float.round(1)
  end

  defp estimate_difficulty(complexity_score, code_block_count, word_count) do
    cond do
      # Very simple content
      complexity_score < 20 and code_block_count == 0 and word_count < 200 ->
        :beginner
      
      # Simple content with some structure
      complexity_score < 40 and code_block_count <= 2 ->
        :beginner
      
      # Moderate complexity with code or longer content
      complexity_score < 60 or (code_block_count <= 5 and word_count < 1000) ->
        :intermediate
      
      # High complexity with lots of code or very long content
      complexity_score < 80 or (code_block_count <= 10 and word_count < 2000) ->
        :advanced
      
      # Very complex content
      true ->
        :expert
    end
  end
end