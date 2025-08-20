use rustler::{Binary, Env, NifResult, Term, Encoder};
use serde_json;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        invalid_markdown,
        processing_error,
    }
}

#[rustler::nif]
fn parse_markdown<'a>(env: Env<'a>, markdown_binary: Binary) -> NifResult<Term<'a>> {
    let markdown_str = match std::str::from_utf8(markdown_binary.as_slice()) {
        Ok(s) => s,
        Err(_) => return Ok((atoms::error(), atoms::invalid_markdown()).encode(env)),
    };

    // Simple word count for now
    let word_count = markdown_str.split_whitespace().count();
    let reading_time = (word_count as f64 / 200.0).ceil() as usize;

    let result = serde_json::json!({
        "links": [],
        "headings": [],
        "code_blocks": [],
        "tasks": [],
        "word_count": word_count,
        "reading_time_minutes": reading_time,
        "metadata": {},
        "table_of_contents": [],
        "backlinks": [],
        "frontmatter": null
    });

    match result.to_string() {
        json_str => Ok((atoms::ok(), json_str).encode(env)),
    }
}

#[rustler::nif]
fn extract_links<'a>(env: Env<'a>, _markdown_binary: Binary) -> NifResult<Term<'a>> {
    let result = serde_json::json!([]);
    match result.to_string() {
        json_str => Ok((atoms::ok(), json_str).encode(env)),
    }
}

#[rustler::nif]
fn extract_headings<'a>(env: Env<'a>, _markdown_binary: Binary) -> NifResult<Term<'a>> {
    let result = serde_json::json!([]);
    match result.to_string() {
        json_str => Ok((atoms::ok(), json_str).encode(env)),
    }
}

#[rustler::nif]
fn validate_links<'a>(env: Env<'a>, _links_json: Binary) -> NifResult<Term<'a>> {
    let result = serde_json::json!([]);
    match result.to_string() {
        json_str => Ok((atoms::ok(), json_str).encode(env)),
    }
}

rustler::init!(
    "Elixir.Kyozo.Storage.MarkdownLD",
    [parse_markdown, extract_links, extract_headings, validate_links]
);