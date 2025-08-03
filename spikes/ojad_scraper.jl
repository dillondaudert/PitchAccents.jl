#!/usr/bin/env julia

using HTTP
using Gumbo
using Cascadia

"""
Scrape the first 20 results from OJAD default search and extract word and accent type.
"""
function scrape_ojad_default()
    # OJAD default search URL (no filters)
    url = "https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index"
    # URL for just nouns, which only have a dictionary from
    noun_url = "https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index/category:6"
    
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
        # Fetch the page
        response = HTTP.get(noun_url, headers=headers)
        
        # Parse HTML
        doc = parsehtml(String(response.body))
        
        println("Parsing HTML structure...")
        
        # Look for the results table
        table_selector = Selector("#word_table tbody tr")
        rows = eachmatch(table_selector, doc.root)
        
        if isempty(rows)
            println("No data rows found. Let's examine the page structure...")
            # Print first 2000 characters to debug
            body_text = String(response.body)
            println("Page content preview:")
            println(body_text[1:min(2000, length(body_text))])
            return
        end
        
        println("Found $(length(rows)) table rows")
        println("\nExtracting word and accent data...")
        println("=" ^ 50)
        
        for row in rows
            
            # The word is in the headline midashi cell.
            headline_sel = Selector("td .midashi .midashi_wrapper .midashi_word")
            headline = nodeText(eachmatch(headline_sel, row)[1])
            println(headline)

            # The jisho form and pitch accent are in the katsuyo_jisho class, under 'accented_word' as a series of 
            # nodes that together define the overall pitch.
            jisho_sel = Selector("td .katsuyo_jisho_js .katsuyo_proc p .katsuyo_accent .accented_word")
            jisho_node = eachmatch(jisho_sel, row)[1]
            # now we iterate through each child 'mola-...' nodes.
            # the mora that has the accent, if any, will have the class 'accent_top'. 
            # Before the 'accent_top', the preceding morae (but not the first mora) will have
            # the class 'accent_plain'.
            # heiban will have no 'accent_top'. 
            morae = []
            println(jisho_node)
            
        end
        return
        
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