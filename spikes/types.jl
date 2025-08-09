"""
Types for representing Japanese words with pitch accent information.
"""

using JSON3
using CodecZlib

"""
Represents a Japanese word with its kanji form (if present), phonetic representation as morae,
and pitch accent pattern. This struct is designed to be hashable for use in hashmaps.

Fields:
- `kanji`: The kanji representation of the word (or kana, if no kanji, or katakana word, etc)
- `morae`: Tuple of mora strings representing the phonetic form
- `accent_idx`: Index of the accent (1-based, 0 for heiban/accentless)

Two JapaneseWord instances are considered equal if all fields match, making this suitable
for deduplication where the same pronunciation+accent with multiple meanings is treated
as the same word unit.
"""
struct JapaneseWord
    kanji::String
    morae::Tuple{Vararg{String}}
    accent_idx::Int
    
    function JapaneseWord(kanji::String, morae::Tuple{Vararg{String}}, accent_idx::Int)
        # Validation
        if accent_idx < 0
            throw(ArgumentError("accent_idx must be non-negative (0 for heiban)"))
        end
        if accent_idx > length(morae)
            throw(ArgumentError("accent_idx cannot exceed number of morae"))
        end
        
        new(kanji, morae, accent_idx)
    end
end

# Constructor for kana-only words
JapaneseWord(morae::Tuple{Vararg{String}}, accent_idx::Int) = JapaneseWord("", morae, accent_idx)

# Implement hash and equality for hashmap usage
Base.hash(w::JapaneseWord, h::UInt) = hash((w.kanji, w.morae, w.accent_idx), h)
Base.:(==)(w1::JapaneseWord, w2::JapaneseWord) = 
    w1.kanji == w2.kanji && w1.morae == w2.morae && w1.accent_idx == w2.accent_idx

# Pretty printing
function Base.show(io::IO, w::JapaneseWord)
    kanji_part = isempty(w.kanji) ? "" : "$(w.kanji)["
    mora_str = join(w.morae, "")
    accent_str = w.accent_idx == 0 ? "0" : "$(w.accent_idx)"
    kanji_end = isempty(w.kanji) ? "" : "]"
    
    print(io, "$(kanji_part)$(mora_str)$(kanji_end) ($(accent_str))")
end

"""
Check if the word is heiban (accentless/flat).
"""
is_heiban(w::JapaneseWord) = w.accent_idx == 0

"""
Get the reading (morae as a single string).
"""
reading(w::JapaneseWord) = join(w.morae, "")

"""
Get the number of morae in the word.
"""
mora_count(w::JapaneseWord) = length(w.morae)

# JSON3 serialization support
JSON3.StructType(::Type{JapaneseWord}) = JSON3.Struct()

"""
Save a collection of JapaneseWord objects to a JSONL file.
Each word is written as one JSON object per line.
If filename contains ".gz", the file will be compressed.
"""
function save_words(words, filename::String)
    if occursin(".gz", filename)
        # Write compressed file
        open(GzipCompressorStream, filename, "w") do io
            for word in words
                println(io, JSON3.write(word))
            end
        end
    else
        # Write uncompressed file
        open(filename, "w") do io
            for word in words
                println(io, JSON3.write(word))
            end
        end
    end
end

"""
Load JapaneseWord objects from a JSONL file.
If filename contains ".gz", the file will be decompressed automatically.
Returns a Vector{JapaneseWord}.
"""
function load_words(filename::String)
    words = JapaneseWord[]
    
    if occursin(".gz", filename)
        # Read compressed file
        open(GzipDecompressorStream, filename, "r") do io
            for line in eachline(io)
                isempty(strip(line)) && continue  # Skip empty lines
                word = JSON3.read(line, JapaneseWord)
                push!(words, word)
            end
        end
    else
        # Read uncompressed file
        open(filename, "r") do io
            for line in eachline(io)
                isempty(strip(line)) && continue  # Skip empty lines
                word = JSON3.read(line, JapaneseWord)
                push!(words, word)
            end
        end
    end
    
    return words
end