# Japanese Pitch Accent Data Sources

This document outlines potential sources for collecting Japanese pitch accent data for research and analysis.

## Potential Data Sources

### Online Dictionaries & Databases

#### OJAD (Online Japanese Accent Dictionary)
- **URL**: https://www.gavo.t.u-tokyo.ac.jp/ojad/eng/pages/home
- **Description**: Comprehensive online dictionary with pitch accent information
- **Data Type**: Word entries with pitch accent patterns
- **Access Method**: TBD - investigate API or scraping possibilities
- **Notes**: Maintained by University of Tokyo

#### Weblio Dictionary
- **URL**: https://www.weblio.jp/
- **Description**: Japanese dictionary with accent information
- **Data Type**: Dictionary entries including pitch accent
- **Access Method**: TBD - investigate web scraping
- **Notes**: Popular online dictionary resource

#### NHK Accent Dictionary
- **Description**: Professional broadcast pronunciation guide
- **Data Type**: Standardized pitch accent patterns
- **Access Method**: TBD - may require physical/digital purchase
- **Notes**: Authoritative source for broadcast Japanese

### Academic & Research Sources

#### BCCWJ (Balanced Corpus of Contemporary Written Japanese)
- **Description**: Large-scale Japanese language corpus
- **Data Type**: May include prosodic annotations
- **Access Method**: TBD - academic access required
- **Notes**: Managed by NINJAL

#### UniDic
- **Description**: Morphological analyzer dictionary
- **Data Type**: Morphological information, may include accent
- **Access Method**: Direct download available
- **Notes**: Part of MeCab ecosystem

### API Sources

#### JMdict/EDICT
- **Description**: Japanese-English dictionary database
- **Data Type**: Dictionary entries, some with accent information
- **Access Method**: XML/JSON download, potential APIs
- **Notes**: Open source, regularly updated

#### Jisho.org API
- **URL**: https://jisho.org/api/
- **Description**: Popular Japanese dictionary with API
- **Data Type**: Dictionary entries
- **Access Method**: REST API
- **Notes**: Limited accent information, but good for word validation

## Data Collection Strategy

### Phase 1: Investigation
- [ ] Test API availability and rate limits
- [ ] Evaluate data quality and coverage
- [ ] Assess legal/ethical considerations for each source
- [ ] Document data formats and structures

### Phase 2: Implementation
- [ ] Develop collection scripts for identified sources
- [ ] Implement data validation and cleaning
- [ ] Design storage format for collected data
- [ ] Set up automated collection pipelines

### Phase 3: Integration
- [ ] Merge data from multiple sources
- [ ] Resolve conflicts and inconsistencies
- [ ] Create unified dataset format
- [ ] Implement quality assurance measures

## Technical Considerations

### Data Format Requirements
- Word/phrase in Japanese (kanji, hiragana, katakana)
- Pitch accent pattern notation
- Reading/pronunciation information
- Part of speech information
- Source attribution

### Collection Methods
1. **API Integration**: For sources with available APIs
2. **Web Scraping**: For sites without APIs (with respect to robots.txt)
3. **Direct Download**: For datasets available for download
4. **Manual Collection**: For specialized or restricted sources

## Legal & Ethical Notes

- Respect robots.txt and terms of service for all sources
- Consider rate limiting to avoid overwhelming servers
- Attribute sources appropriately in research
- Ensure compliance with academic fair use policies

---

## Detailed Source Analysis

### OJAD (Online Japanese Accent Dictionary) - Detailed Analysis

**Base URL**: https://www.gavo.t.u-tokyo.ac.jp/ojad/

**Search Endpoint**: `https://www.gavo.t.u-tokyo.ac.jp/ojad/search/index/`

#### Data Structure
- **Dictionary Forms**: Primary verb forms (e.g., あく, いく, うる)
- **Conjugations**: Multiple forms including:
  - ます form (polite)
  - て form (conjunctive)
  - た form (past)
  - ない form (negative)
  - られる form (potential/passive)

#### Accent Pattern Encoding
- **Type Classification**:
  - Type 0: Flat accent (平板型) - no pitch drop
  - Type 1: Head-high (頭高型) - drop after first mora
  - Type 2+: Mid-high (中高型) - drop after specified mora
  - Type -1: Tail-high (尾高型) - drop at word boundary

#### Search Parameters
- `textbook`: Filter by textbook source (1, 2, etc.)
- `sortprefix`: Sorting method (`accent`)
- `narabi1`: Primary sort (`kata_asc` - katakana ascending)
- `narabi2`: Secondary sort (`accent_asc` - accent ascending)
- `narabi3`: Tertiary sort (`mola_asc` - mora ascending)
- `yure`: Accent variation display (`visible`/`invisible`)
- `curve`: Pitch curve display (`visible`/`invisible`)
- `details`: Detailed view (`visible`/`invisible`)
- `limit`: Results per page (default: 20)

#### Data Fields Available
- **Word**: Dictionary form in hiragana/katakana
- **Accent Type**: Numerical classification (0, 1, 2, 3, etc.)
- **Mora Count**: Number of phonetic units
- **Part of Speech**: Grammatical classification
- **Difficulty Level**: Learning difficulty rating
- **Textbook Source**: Reference to educational materials
- **Conjugation Forms**: Complete verb paradigms

#### Access Considerations
- **Rate Limiting**: Implement delays between requests
- **Pagination**: Handle 20-item limit per page
- **User-Agent**: Use appropriate headers for academic research
- **Language Interface**: Supports Japanese and English interfaces