#!/usr/bin/env julia

using HTTP
using Gumbo
using Cascadia


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

"""
    parse_midashi

Split the headline (midashi) on the separators for masu-desu, い, な adjectives.
Return just the jisho form headline.
"""
function parse_midashi(headline)
    sep_re = r"(\[な\])?・"
    midashi = split(headline, sep_re)[1]
    return String(midashi)
end

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
    morae = String[]
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
    
    return (morae, accent_idx)
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
Scrape jisho form for all nouns from OJAD, returning a list of JapaneseWord structs.
"""
function _scrape_ojad_url(url, headers, part_of_speech::String)
    
    println("Fetching search results for $url...")

    try
        # First, get the first page to determine total pages
        response = HTTP.get(url, headers=headers)
        doc = parsehtml(String(response.body))
        
        total_pages = get_total_pages(doc)
        println("Found $total_pages total pages")

        words = JapaneseWord[]
        
        # Process all pages
        for page in 1:total_pages
            println("\n" * "=" ^ 60)
            println("Processing page $page of $total_pages")
            println("=" ^ 60)
            
            # Construct URL for current page
            page_url = if page == 1
                url
            else
                "$url/page:$page"
            end
            
            # Fetch page if not the first one (already fetched)
            if page > 1
                response = HTTP.get(page_url, headers=headers)
                doc = parsehtml(String(response.body))
                sleep(.4)  # Be respectful with rate limiting
            end
            
            # Look for the results table
            table_selector = Selector("#word_table tbody tr")
            # Rows of words, each will have multiple 活動 katsudo
            rows = eachmatch(table_selector, doc.root)
            
            if isempty(rows)
                println("No data rows found on page $page")
                continue
            end
            
            println("Found $(length(rows)) table rows on page $page")
            
            for row in rows
                # The word is in the headline midashi cell.
                headline_sel = Selector("td .midashi .midashi_wrapper .midashi_word")
                local midashi
                try
                    midashi = parse_midashi(nodeText(eachmatch(headline_sel, row)[1]))
                catch
                    println("Row $row didn't have a headline, skipping")
                    continue
                end

                # The jisho form and pitch accent are in the katsuyo_jisho class, under 'accented_word' as a series of 
                # nodes that together define the overall pitch. There can be MULTIPLE accent patterns per word.
                jisho_sel = Selector("td .katsuyo_jisho_js .katsuyo_proc p .katsuyo_accent .accented_word")
                jisho_nodes = eachmatch(jisho_sel, row)
                
                # Process each accent pattern for this word, saved as a different struct
                # NOTE: If there are no jisho nodes, this word won't be recorded (correct behavior)
                for jisho_node in jisho_nodes
                    morae, accent_idx = parse_accented_word(jisho_node)
                    kanji_word = JapaneseWord(midashi, morae, accent_idx, part_of_speech)
                    println(kanji_word)
                    push!(words, kanji_word)
                end
            end
        end
        
        println("\nCompleted scraping all $total_pages pages")
        return words
        
    catch e
        println("Error occurred: $e")
        if isa(e, HTTP.ExceptionRequest.StatusError)
            println("HTTP Status: $(e.status)")
            println("Response body preview:")
            println(String(e.response.body)[1:min(500, end)])
        end
        error()
    end

end

"""
Scrape all results from OJAD nouns, verbs, and adjectives. Jisho form only for now.
Save the results into the designated file.
"""
function scrape_ojad(outfile)
    
    noun_url = "https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index/category:6/limit:100"
    i_adj_url = "https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index/category:4/limit:100"
    na_adj_url = "https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index/category:5/limit:100"
    verb_url = "https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index/category:verb/limit:100"
    urls = [(noun_url, "noun"), (i_adj_url, "adjective"), (na_adj_url, "adjective"), (verb_url, "verb")]
    
    # Set headers to avoid being blocked
    headers = [
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language" => "en-US,en;q=0.5",
        "Accept-Encoding" => "gzip, deflate",
        "Connection" => "keep-alive"
    ]

    words = JapaneseWord[]
    for (url, pos) in urls
        append!(words, _scrape_ojad_url(url, headers, pos))
    end

    save_words(words, outfile)
    
end