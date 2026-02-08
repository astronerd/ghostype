#!/usr/bin/env python3
"""
Test English in-sentence patterns for American users
Pure English Block 2 - no Chinese mixed in
"""

import urllib.request
import json
import time
import ssl

# API Config
BASE_URL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
API_KEY = "3b108766-4683-4948-8d84-862b104a5a3e"
MODEL_NAME = "doubao-seed-1-6-flash-250828"

# Block 1: Basic English Polish
BLOCK1_ENGLISH = """You are a professional text polishing assistant. Polish the user's voice input to make it more fluent and natural.

Rules:
- Fix speech recognition errors
- Add appropriate punctuation
- Keep the original meaning, don't over-modify
- Remove filler words (um, uh, like, you know, basically, etc.)
- Output only the polished text, no explanations"""

# Block 2: English In-Sentence Pattern Recognition
BLOCK2_ENGLISH = """
[In-Sentence Pattern Recognition]

During polishing, identify and process these special patterns:

1. Email Address Dictation
   - Users spell out email addresses verbally
   - "at" → @
   - "dot" → .
   - "no H" / "with no H" / "without H" → remove H from previous word
   - "all lowercase" / "all caps" → adjust case
   - "underscore" → _
   - "dash" / "hyphen" → -
   - Examples:
     * "sara with no H at gmail dot com" → "sara@gmail.com"
     * "john underscore doe at company dot com" → "john_doe@company.com"
     * "mike dot smith at acme dot co" → "mike.smith@acme.co"
     * "contact at MAKR M A K R dot com" → "contact@makr.com"

2. Phone Number Dictation
   - Users say phone numbers with verbal separators
   - "area code" indicates start of phone number
   - Examples:
     * "area code 415 555 1234" → "(415) 555-1234"
     * "call me at 800 555 0199" → "800-555-0199"
     * "my number is 1 800 FLOWERS" → "1-800-FLOWERS"

3. URL/Website Dictation
   - "dot" → .
   - "slash" → /
   - "colon" → :
   - "www" or "double u double u double u" → www
   - "HTTP" / "HTTPS" → http:// or https://
   - Examples:
     * "go to www dot example dot com" → "www.example.com"
     * "visit HTTPS colon slash slash github dot com" → "https://github.com"
     * "check out example dot com slash pricing" → "example.com/pricing"

4. Name Spelling Confirmation
   - Users spell names to clarify pronunciation/spelling
   - Remove the spelling, keep only the name
   - Examples:
     * "My name is Sean S E A N" → "My name is Sean"
     * "Contact Jennifer J E N N I F E R at sales" → "Contact Jennifer at sales"
     * "Ask for Siobhan thats S I O B H A N" → "Ask for Siobhan"
     * "Its Stephen with a P H" → "Its Stephen"

5. Acronym/Abbreviation Spelling
   - When users spell out acronyms letter by letter
   - Examples:
     * "Send it to the C E O" → "Send it to the CEO"
     * "The A P I is down" → "The API is down"
     * "Contact H R department" → "Contact HR department"

6. Special Characters
   - "hashtag" / "pound sign" → #
   - "at sign" / "at symbol" → @
   - "ampersand" → &
   - "percent" / "percent sign" → %
   - "dollar sign" → $
   - "asterisk" / "star" → *
   - Examples:
     * "use hashtag ghosttype" → "use #ghosttype"
     * "price is dollar sign 99" → "price is $99"
     * "50 percent off" → "50% off"

7. New Line / Paragraph
   - "new line" / "next line" → insert line break
   - "new paragraph" / "next paragraph" → insert paragraph break
   - Examples:
     * "First point new line second point" → "First point\\nSecond point"

8. Punctuation Commands
   - "period" / "full stop" → .
   - "comma" → ,
   - "question mark" → ?
   - "exclamation point" / "exclamation mark" → !
   - "colon" → :
   - "semicolon" → ;
   - "open quote" / "close quote" → " "
   - "open paren" / "close paren" → ( )
   - Examples:
     * "What do you think question mark" → "What do you think?"
     * "Note colon this is important" → "Note: this is important"

[Processing Rules]
- Convert verbal descriptions to actual characters/formats
- Remove spelling confirmations and keep only the word itself
- Remove filler words (um, uh, like, you know, so, basically, I mean, right)
- If intent is unclear, keep original text
"""

# Block 3: English Trigger Commands
BLOCK3_ENGLISH = """
[End-of-Sentence Commands]

When user says "{{trigger_word}}" followed by a command at the end, execute that command.

[Supported Commands]

1. Tone Commands
   - "{{trigger_word}} make it professional" → formal business tone
   - "{{trigger_word}} make it casual" → friendly casual tone
   - "{{trigger_word}} make it polite" → more courteous
   - "{{trigger_word}} more formal" → formal style
   - "{{trigger_word}} more friendly" → warmer tone

2. Format Commands
   - "{{trigger_word}} make a list" / "as a list" → bullet/numbered list
   - "{{trigger_word}} action items" → extract action items
   - "{{trigger_word}} meeting notes" → format as meeting notes
   - "{{trigger_word}} email format" → format as email

3. Length Commands
   - "{{trigger_word}} shorter" / "make it brief" → condense
   - "{{trigger_word}} expand" / "more detail" → elaborate
   - "{{trigger_word}} summarize" → key points only

4. Translation Commands
   - "{{trigger_word}} translate to Chinese" → translate to Chinese
   - "{{trigger_word}} translate to Spanish" → translate to Spanish
   - "{{trigger_word}} in French" → translate to French

5. Context Commands
   - "{{trigger_word}} for my boss" → appropriate for manager
   - "{{trigger_word}} for the client" → client-appropriate
   - "{{trigger_word}} for the team" → team communication style

[Rules]
- Execute command and output result only
- Don't include the trigger word or command in output
- If command is unclear, try to understand intent
"""

def build_english_prompt(enable_block2=True, enable_block3=True, trigger_word="ghost"):
    """Build complete English system prompt"""
    prompt = BLOCK1_ENGLISH
    
    if enable_block2:
        prompt += "\n\n" + BLOCK2_ENGLISH
    
    if enable_block3:
        prompt += "\n\n" + BLOCK3_ENGLISH.replace("{{trigger_word}}", trigger_word)
    
    return prompt

def call_api(system_prompt, user_message):
    """Call Doubao API"""
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
    
    payload = {
        "model": MODEL_NAME,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ],
        "temperature": 0.7,
        "max_tokens": 2048
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(BASE_URL, data=data, headers=headers, method='POST')
    ctx = ssl.create_default_context()
    
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result["choices"][0]["message"]["content"].strip()
    except Exception as e:
        return f"Error: {str(e)}"

def test_case(name, input_text, expected, trigger_word="ghost"):
    """Run single test case"""
    print(f"\n{'='*60}")
    print(f"📝 Test: {name}")
    print(f"{'='*60}")
    print(f"Input: {input_text}")
    print(f"Expected: {expected}")
    
    prompt = build_english_prompt(trigger_word=trigger_word)
    result = call_api(prompt, input_text)
    
    print(f"Output: {result}")
    print("-" * 60)
    
    time.sleep(0.5)
    return result

def main():
    print("\n" + "="*70)
    print("🇺🇸 English In-Sentence Pattern Recognition Test")
    print("="*70)
    
    # ========== Email Address Tests ==========
    print("\n\n" + "📧"*25)
    print("EMAIL ADDRESS DICTATION")
    print("📧"*25)
    
    test_case(
        "Email - Basic",
        "my email is john at gmail dot com",
        "my email is john@gmail.com"
    )
    
    test_case(
        "Email - With 'no H'",
        "contact sara with no H at gmail dot com",
        "contact sara@gmail.com"
    )
    
    test_case(
        "Email - Company domain",
        "send it to mike at MAKR M A K R dot com",
        "send it to mike@makr.com"
    )
    
    test_case(
        "Email - With underscore",
        "email me at john underscore doe at company dot com",
        "email me at john_doe@company.com"
    )
    
    test_case(
        "Email - With dot in name",
        "reach me at mike dot smith at acme dot co",
        "reach me at mike.smith@acme.co"
    )
    
    test_case(
        "Email - Complex",
        "the support email is help dash desk at tech underscore corp dot io",
        "the support email is help-desk@tech_corp.io"
    )
    
    # ========== Phone Number Tests ==========
    print("\n\n" + "📞"*25)
    print("PHONE NUMBER DICTATION")
    print("📞"*25)
    
    test_case(
        "Phone - With area code",
        "call me at area code 415 555 1234",
        "call me at (415) 555-1234"
    )
    
    test_case(
        "Phone - Toll free",
        "our number is 1 800 555 0199",
        "our number is 1-800-555-0199"
    )
    
    test_case(
        "Phone - Simple",
        "my cell is 555 123 4567",
        "my cell is 555-123-4567"
    )
    
    # ========== URL Tests ==========
    print("\n\n" + "🌐"*25)
    print("URL/WEBSITE DICTATION")
    print("🌐"*25)
    
    test_case(
        "URL - Basic www",
        "go to www dot example dot com",
        "go to www.example.com"
    )
    
    test_case(
        "URL - With path",
        "check out example dot com slash pricing",
        "check out example.com/pricing"
    )
    
    test_case(
        "URL - HTTPS",
        "visit https colon slash slash github dot com",
        "visit https://github.com"
    )
    
    # ========== Name Spelling Tests ==========
    print("\n\n" + "✏️"*25)
    print("NAME SPELLING CONFIRMATION")
    print("✏️"*25)
    
    test_case(
        "Name - Letter by letter",
        "My name is Sean S E A N",
        "My name is Sean"
    )
    
    test_case(
        "Name - With context",
        "Please contact Jennifer J E N N I F E R in sales",
        "Please contact Jennifer in sales"
    )
    
    test_case(
        "Name - Unusual spelling",
        "Ask for Siobhan thats S I O B H A N",
        "Ask for Siobhan"
    )
    
    test_case(
        "Name - With PH",
        "Its Stephen with a P H not Steven",
        "Its Stephen"
    )
    
    test_case(
        "Name - Multiple names",
        "The team lead is Caitlin C A I T L I N and her manager is Geoff G E O F F",
        "The team lead is Caitlin and her manager is Geoff"
    )
    
    # ========== Acronym Tests ==========
    print("\n\n" + "🔤"*25)
    print("ACRONYM SPELLING")
    print("🔤"*25)
    
    test_case(
        "Acronym - CEO",
        "Send the report to the C E O",
        "Send the report to the CEO"
    )
    
    test_case(
        "Acronym - API",
        "The A P I is returning errors",
        "The API is returning errors"
    )
    
    test_case(
        "Acronym - HR",
        "Talk to H R about the benefits",
        "Talk to HR about the benefits"
    )
    
    test_case(
        "Acronym - Multiple",
        "The C T O wants the A P I docs sent to Q A",
        "The CTO wants the API docs sent to QA"
    )
    
    # ========== Special Characters Tests ==========
    print("\n\n" + "🔣"*25)
    print("SPECIAL CHARACTERS")
    print("🔣"*25)
    
    test_case(
        "Special - Hashtag",
        "use hashtag ghosttype on social media",
        "use #ghosttype on social media"
    )
    
    test_case(
        "Special - Dollar",
        "the price is dollar sign 99 dot 99",
        "the price is $99.99"
    )
    
    test_case(
        "Special - Percent",
        "we got 50 percent off the order",
        "we got 50% off the order"
    )
    
    test_case(
        "Special - Ampersand",
        "the company is called Smith ampersand Jones",
        "the company is called Smith & Jones"
    )
    
    # ========== Punctuation Tests ==========
    print("\n\n" + "❓"*25)
    print("PUNCTUATION COMMANDS")
    print("❓"*25)
    
    test_case(
        "Punctuation - Question",
        "What do you think question mark",
        "What do you think?"
    )
    
    test_case(
        "Punctuation - Colon",
        "Note colon this is important",
        "Note: this is important"
    )
    
    test_case(
        "Punctuation - Exclamation",
        "Great job exclamation point",
        "Great job!"
    )
    
    # ========== New Line Tests ==========
    print("\n\n" + "↩️"*25)
    print("NEW LINE / PARAGRAPH")
    print("↩️"*25)
    
    test_case(
        "New line - Basic",
        "First item new line second item new line third item",
        "First item\nSecond item\nThird item"
    )
    
    test_case(
        "Paragraph",
        "This is paragraph one new paragraph this is paragraph two",
        "This is paragraph one\n\nThis is paragraph two"
    )
    
    # ========== Filler Word Removal Tests ==========
    print("\n\n" + "🗑️"*25)
    print("FILLER WORD REMOVAL")
    print("🗑️"*25)
    
    test_case(
        "Fillers - Heavy",
        "So um like I was thinking that you know maybe we should basically um reconsider the approach",
        "I was thinking that maybe we should reconsider the approach"
    )
    
    test_case(
        "Fillers - Business context",
        "Um so basically the client said that like they need more time you know",
        "The client said that they need more time"
    )
    
    # ========== Combined Patterns Tests ==========
    print("\n\n" + "🔀"*25)
    print("COMBINED PATTERNS")
    print("🔀"*25)
    
    test_case(
        "Combined - Email + Fillers",
        "So um you can reach me at like sara with no H at gmail dot com you know",
        "You can reach me at sara@gmail.com"
    )
    
    test_case(
        "Combined - Name + Email",
        "Contact John Smith J O H N at john dot smith at company dot com",
        "Contact John Smith at john.smith@company.com"
    )
    
    test_case(
        "Combined - Full contact info",
        "My name is Mike M I K E my email is mike at acme dot com and my number is 555 123 4567",
        "My name is Mike, my email is mike@acme.com and my number is 555-123-4567"
    )
    
    # ========== Real World Scenarios ==========
    print("\n\n" + "🌍"*25)
    print("REAL WORLD SCENARIOS")
    print("🌍"*25)
    
    test_case(
        "Scenario - Leaving voicemail",
        "Hi this is Jennifer J E N N I F E R from Acme Corp please call me back at area code 415 555 1234 or email me at jennifer at acme dot com thanks",
        "Hi, this is Jennifer from Acme Corp. Please call me back at (415) 555-1234 or email me at jennifer@acme.com. Thanks."
    )
    
    test_case(
        "Scenario - Giving directions",
        "Go to www dot company dot com slash support and click on the help link",
        "Go to www.company.com/support and click on the help link."
    )
    
    test_case(
        "Scenario - Business intro",
        "Um so like my name is Stephen with a P H and Im the C T O at Tech Corp you can reach me at stephen at techcorp dot io",
        "My name is Stephen and I'm the CTO at Tech Corp. You can reach me at stephen@techcorp.io."
    )
    
    # ========== With Ghost Commands ==========
    print("\n\n" + "👻"*25)
    print("WITH GHOST COMMANDS")
    print("👻"*25)
    
    test_case(
        "Ghost - Email formal",
        "hey so um my email is john at company dot com let me know if you need anything ghost make it professional",
        "My email is john@company.com. Please let me know if you need anything."
    )
    
    test_case(
        "Ghost - Contact info as list",
        "you can reach me at mike at gmail dot com or call 555 123 4567 ghost make a list",
        "- Email: mike@gmail.com\n- Phone: 555-123-4567"
    )
    
    test_case(
        "Ghost - Casual meeting request",
        "So um I was thinking we should like meet tomorrow at 2 to discuss the A P I issues ghost for my boss",
        "I'd like to schedule a meeting tomorrow at 2 PM to discuss the API issues."
    )
    
    print("\n\n" + "="*70)
    print("✅ English Test Complete!")
    print("="*70)

if __name__ == "__main__":
    main()
