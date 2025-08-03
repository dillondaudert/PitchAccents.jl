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
        response = HTTP.get(url, headers=headers)
        
        # Parse HTML
        doc = parsehtml(String(response.body))
        
        println("Parsing HTML structure...")
        
        # Look for the results table
        table_selector = Selector("#word_table tbody tr")
        rows = eachmatch(table_selector, doc.root)
        
        if isempty(rows)
            println("No table rows found. Trying alternative selectors...")
            # Try alternative selectors
            alt_selectors = [
                "table tbody tr",
                ".search-results tr",
                "tr"
            ]
            
            for selector_str in alt_selectors
                selector = Selector(selector_str)
                rows = eachmatch(selector, doc.root)
                if !isempty(rows)
                    println("Found $(length(rows)) rows with selector: $selector_str")
                    break
                end
            end
        end
        
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
        
        count = 0
        for (i, row) in enumerate(rows)
            if count >= 20
                break
            end
            
            # Extract text from all cells in the row
            cells = eachmatch(Selector("td"), row)
            
            if !isempty(cells)
                count += 1
                
                # Extract word (typically in first column)
                word = ""
                accent_type = ""
                
                # Get text from first cell (word)
                if length(cells) >= 1
                    word_cell = cells[1]
                    word = strip(nodeText(word_cell))
                end
                
                # Look for accent information in subsequent cells or attributes
                for cell in cells
                    cell_text = strip(nodeText(cell))
                    # Look for accent type patterns
                    if occursin(r"[0-9]+型|平板|頭高|中高|尾高", cell_text)
                        accent_type = cell_text
                        break
                    end
                end
                
                # If no accent info found in cells, check for data attributes or classes
                if isempty(accent_type)
                    # Check for class names that might indicate accent type
                    for cell in cells
                        if haskey(attrs(cell), "class")
                            class_attr = attrs(cell)["class"]
                            if occursin(r"accent|type", class_attr)
                                accent_type = "Class: $class_attr"
                                break
                            end
                        end
                    end
                end
                
                if isempty(accent_type)
                    accent_type = "Unknown"
                end
                
                println("$count. Word: '$word' | Accent: '$accent_type'")
            end
        end
        
        if count == 0
            println("No valid word entries found in table rows.")
            println("\nDebug: Examining page structure...")
            
            # Look for any text that might contain Japanese words
            all_text = nodeText(doc.root)
            japanese_matches = collect(eachmatch(r"[\p{Hiragana}\p{Katakana}\p{Han}]+", all_text))
            
            if !isempty(japanese_matches)
                println("Found Japanese text in page:")
                for (i, match) in enumerate(japanese_matches[1:min(10, end)])
                    println("  $i. $(match.match)")
                end
            else
                println("No Japanese text found in page content.")
            end
        end
        
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