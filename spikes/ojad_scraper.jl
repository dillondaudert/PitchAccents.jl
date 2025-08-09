#!/usr/bin/env julia

using HTTP
using Gumbo
using Cascadia
include("types.jl")

"""
Given an `accented_word` node, of the following example format 
(this word is heiban):

<html>
<span class="accented_word">
    <span class="mola_-3">
        <span class="inner">
            <span class="char">ひ</span>
            <span class="char">ょ</span>
        </span>
    </span>
    <span class=" accent_plain mola_-2">
        <span class="inner">
            <span class="char">う</span>
        </span>
    </span>
    <span class=" accent_plain mola_-1">
        <span class="inner">
            <span class="char">じ</span>
        </span>
    </span>
</span>
</html>

Extract the kana representation of a word along with accent information.
For Tokyo-style pitch accent, if a word has an accent, then one character 
will have the class `accent_top`. The morae before the accent will be low
(first mora only), or have the `accent_plain` class. We can encode the 
index of the accent by its position (starting at 1), otherwise 0 if 平板.

The return is a tuple (morae, accent_idx). The first element is a tuple 
of the morae comprising the word, the second element is an integer index
where the accent is (or 0 for accentless). 
"""
function parse_accented_word(node)
    morae = []
    accent_idx = 0
    
    # Find all mola span elements that contain the mora characters
    mola_selector = Selector("span[class*='mola_']")
    mola_spans = eachmatch(mola_selector, node)
    
    for (i, mola_span) in enumerate(mola_spans)
        # Extract the character(s) from the inner span
        char_selector = Selector(".inner .char")
        char_nodes = eachmatch(char_selector, mola_span)
        
        # Concatenate all characters in this mora
        mora_text = join([nodeText(char_node) for char_node in char_nodes], "")
        push!(morae, mora_text)
        
        # Check if this mora has the accent (accent_top class)
        if occursin("accent_top", get(mola_span.attributes, "class", ""))
            accent_idx = i
        end
    end
    
    return (tuple(morae...), accent_idx)
end

"""
Extract the total number of pages from the paginator div.
Returns the total page count as an integer.
"""
function get_total_pages(doc)
    # Find the paginator div
    paginator_selector = Selector("#paginator")
    paginator_nodes = eachmatch(paginator_selector, doc.root)
    
    if isempty(paginator_nodes)
        return 1  # Default to 1 page if no paginator found
    end
    
    paginator = paginator_nodes[1]
    
    # Look for all numeric page links - the highest number is the total pages
    link_selector = Selector("a")
    links = eachmatch(link_selector, paginator)
    
    max_page = 1
    for link in links
        link_text = strip(nodeText(link))
        # Parse numeric page links, skip "次へ" and other non-numeric links
        if occursin(r"^\d+$", link_text)
            page_num = parse(Int, link_text)
            max_page = max(max_page, page_num)
        end
    end
    
    return max_page
end

"""
Scrape all results from OJAD nouns and extract word and accent type.
"""
function scrape_ojad_default()
    # Base URL for nouns
    base_url = "https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index/category:6/limit:100"
    
    println("Fetching OJAD search results...")
    
    # Set headers to avoid being blocked
    headers = [
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language" => "en-US,en;q=0.5",
        "Accept-Encoding" => "gzip, deflate",
        "Connection" => "keep-alive"
    ]
    
    try
        # First, get the first page to determine total pages
        response = HTTP.get(base_url, headers=headers)
        doc = parsehtml(String(response.body))
        
        total_pages = get_total_pages(doc)
        println("Found $total_pages total pages")

        words::Vector{JapaneseWord} = JapaneseWord[]
        
        # Process all pages
        for page in 1:total_pages
            println("\n" * "=" ^ 60)
            println("Processing page $page of $total_pages")
            println("=" ^ 60)
            
            # Construct URL for current page
            page_url = if page == 1
                base_url
            else
                "$base_url/page:$page"
            end
            
            # Fetch page if not the first one (already fetched)
            if page > 1
                response = HTTP.get(page_url, headers=headers)
                doc = parsehtml(String(response.body))
                sleep(1)  # Be respectful with rate limiting
            end
            
            # Look for the results table
            table_selector = Selector("#word_table tbody tr")
            rows = eachmatch(table_selector, doc.root)
            
            if isempty(rows)
                println("No data rows found on page $page")
                continue
            end
            
            println("Found $(length(rows)) table rows on page $page")
            
            for row in rows
                # The word is in the headline midashi cell.
                headline_sel = Selector("td .midashi .midashi_wrapper .midashi_word")
                headline = nodeText(eachmatch(headline_sel, row)[1])

                # The jisho form and pitch accent are in the katsuyo_jisho class, under 'accented_word' as a series of 
                # nodes that together define the overall pitch.
                jisho_sel = Selector("td .katsuyo_jisho_js .katsuyo_proc p .katsuyo_accent .accented_word")
                jisho_node = eachmatch(jisho_sel, row)[1]
                morae, accent_idx = parse_accented_word(jisho_node)
                kanji_word = JapaneseWord(headline, morae, accent_idx)
                println(kanji_word)
                push!(words, kanji_word)
            end
            break
        end

        save_words(words, "saved_words")
        
        println("\nCompleted scraping all $total_pages pages")
        
    catch e
        println("Error occurred: $e")
        if isa(e, HTTP.ExceptionRequest.StatusError)
            println("HTTP Status: $(e.status)")
            println("Response body preview:")
            println(String(e.response.body)[1:min(500, end)])
        end
    end
end

# Helper function to extract text content from a node
function nodeText(node)
    if isa(node, HTMLText)
        return node.text
    elseif isa(node, HTMLElement)
        return join([nodeText(child) for child in node.children], "")
    else
        return ""
    end
end

# Run the scraper
if abspath(PROGRAM_FILE) == @__FILE__
    scrape_ojad_default()
end