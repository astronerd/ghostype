# Color Palettes & Typography Guide

## Industry-Specific Color Palettes

### Tech & SaaS

**Modern SaaS (Indigo)**
```
Primary:    #6366F1 (Indigo 500)
Secondary:  #8B5CF6 (Violet 500)
Accent:     #10B981 (Emerald 500)
Background: #F8FAFC (Slate 50)
Surface:    #FFFFFF
Text:       #1E293B (Slate 800)
Muted:      #64748B (Slate 500)
```

**Developer Tools (Dark)**
```
Primary:    #3B82F6 (Blue 500)
Secondary:  #22D3EE (Cyan 400)
Accent:     #A78BFA (Violet 400)
Background: #0F172A (Slate 900)
Surface:    #1E293B (Slate 800)
Text:       #F1F5F9 (Slate 100)
Muted:      #94A3B8 (Slate 400)
```

### Finance & Fintech

**Trust Blue**
```
Primary:    #0EA5E9 (Sky 500)
Secondary:  #14B8A6 (Teal 500)
Accent:     #F59E0B (Amber 500)
Background: #FFFFFF
Surface:    #F0F9FF (Sky 50)
Text:       #0F172A (Slate 900)
Success:    #22C55E (Green 500)
Error:      #EF4444 (Red 500)
```

**Crypto/Web3**
```
Primary:    #8B5CF6 (Violet 500)
Secondary:  #EC4899 (Pink 500)
Accent:     #14B8A6 (Teal 500)
Background: #0A0A0A
Surface:    #171717
Text:       #FAFAFA
Muted:      #A1A1AA
```

### Healthcare

**Medical Clean**
```
Primary:    #0891B2 (Cyan 600)
Secondary:  #059669 (Emerald 600)
Accent:     #7C3AED (Violet 600)
Background: #FFFFFF
Surface:    #F0FDFA (Teal 50)
Text:       #134E4A (Teal 900)
Muted:      #5EEAD4 (Teal 300)
```

### Wellness & Beauty

**Spa Serenity**
```
Primary:    #E8B4B8 (Soft Pink)
Secondary:  #A8D5BA (Sage Green)
Accent:     #D4AF37 (Gold)
Background: #FFF5F5 (Warm White)
Surface:    #FFFFFF
Text:       #2D3436 (Charcoal)
Muted:      #636E72
```

**Natural Wellness**
```
Primary:    #84CC16 (Lime 500)
Secondary:  #22C55E (Green 500)
Accent:     #F97316 (Orange 500)
Background: #FEFCE8 (Yellow 50)
Surface:    #FFFFFF
Text:       #365314 (Lime 900)
Muted:      #65A30D (Lime 600)
```

### E-commerce

**Luxury**
```
Primary:    #1C1917 (Stone 900)
Secondary:  #D4AF37 (Gold)
Accent:     #78716C (Stone 500)
Background: #FAFAF9 (Stone 50)
Surface:    #FFFFFF
Text:       #1C1917 (Stone 900)
Muted:      #A8A29E (Stone 400)
```

**Vibrant Retail**
```
Primary:    #F97316 (Orange 500)
Secondary:  #EC4899 (Pink 500)
Accent:     #8B5CF6 (Violet 500)
Background: #FFFFFF
Surface:    #FFF7ED (Orange 50)
Text:       #1C1917 (Stone 900)
Muted:      #78716C (Stone 500)
```

---

## Typography Pairings

### Professional & Corporate

**Inter / Inter**
- Mood: Clean, professional, neutral
- Best For: SaaS, enterprise, dashboards
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');`

**IBM Plex Sans / IBM Plex Mono**
- Mood: Technical, trustworthy
- Best For: Developer tools, documentation
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono&display=swap');`

### Modern & Friendly

**Poppins / Open Sans**
- Mood: Friendly, approachable, modern
- Best For: Startups, apps, e-commerce
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&family=Open+Sans:wght@400;600&display=swap');`

**DM Sans / DM Sans**
- Mood: Geometric, contemporary
- Best For: Tech products, modern brands
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700&display=swap');`

### Elegant & Luxury

**Cormorant Garamond / Montserrat**
- Mood: Elegant, calming, sophisticated
- Best For: Luxury brands, wellness, beauty, editorial
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600&family=Montserrat:wght@400;500;600&display=swap');`

**Playfair Display / Source Sans Pro**
- Mood: Sophisticated, editorial
- Best For: Editorial, luxury brands, magazines
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;500;600;700&family=Source+Sans+Pro:wght@400;600&display=swap');`

### Tech & Innovation

**Space Grotesk / DM Sans**
- Mood: Tech-forward, innovative
- Best For: Developer tools, AI products, tech startups
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=DM+Sans:wght@400;500&display=swap');`

**JetBrains Mono / Inter**
- Mood: Developer-focused, technical
- Best For: Code editors, developer tools
- Google Fonts: `@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Inter:wght@400;500;600&display=swap');`

---

## Typography Scale

Use a consistent type scale:

```css
--text-xs: 0.75rem;    /* 12px */
--text-sm: 0.875rem;   /* 14px */
--text-base: 1rem;     /* 16px */
--text-lg: 1.125rem;   /* 18px */
--text-xl: 1.25rem;    /* 20px */
--text-2xl: 1.5rem;    /* 24px */
--text-3xl: 1.875rem;  /* 30px */
--text-4xl: 2.25rem;   /* 36px */
--text-5xl: 3rem;      /* 48px */
--text-6xl: 3.75rem;   /* 60px */
```

## Line Heights

```css
--leading-tight: 1.25;
--leading-snug: 1.375;
--leading-normal: 1.5;
--leading-relaxed: 1.625;
--leading-loose: 2;
```
