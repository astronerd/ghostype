# Design System Generation Guide

## How to Generate a Design System

When a user requests UI/UX work, follow this process:

### Step 1: Identify the Product Type

Determine the industry/category:
- Tech & SaaS: SaaS, Micro SaaS, B2B Enterprise, Developer Tools, AI/Chatbot Platform
- Finance: Fintech, Banking, Crypto, Insurance, Trading Dashboard
- Healthcare: Medical Clinic, Pharmacy, Dental, Veterinary, Mental Health
- E-commerce: General, Luxury, Marketplace, Subscription Box
- Services: Beauty/Spa, Restaurant, Hotel, Legal, Consulting
- Creative: Portfolio, Agency, Photography, Gaming, Music Streaming
- Emerging Tech: Web3/NFT, Spatial Computing, Quantum Computing

### Step 2: Select Appropriate Style

Choose from 67 available styles based on the product type:

**General Styles (Top Recommendations):**
| Style | Best For |
|-------|----------|
| Minimalism & Swiss Style | Enterprise apps, dashboards, documentation |
| Neumorphism | Health/wellness apps, meditation platforms |
| Glassmorphism | Modern SaaS, financial dashboards |
| Brutalism | Design portfolios, artistic projects |
| Claymorphism | Educational apps, children's apps, SaaS |
| Dark Mode (OLED) | Night-mode apps, coding platforms |
| Soft UI Evolution | Modern enterprise apps, SaaS |
| Neubrutalism | Gen Z brands, startups, Figma-style |
| Bento Box Grid | Dashboards, product pages, portfolios |
| AI-Native UI | AI products, chatbots, copilots |

**Landing Page Styles:**
| Style | Best For |
|-------|----------|
| Hero-Centric Design | Products with strong visual identity |
| Conversion-Optimized | Lead generation, sales pages |
| Feature-Rich Showcase | SaaS, complex products |
| Social Proof-Focused | Services, B2C products |

### Step 3: Generate Color Palette

Select industry-appropriate colors:

**Example Palettes:**

**Wellness/Spa:**
- Primary: #E8B4B8 (Soft Pink)
- Secondary: #A8D5BA (Sage Green)
- CTA: #D4AF37 (Gold)
- Background: #FFF5F5 (Warm White)
- Text: #2D3436 (Charcoal)

**SaaS/Tech:**
- Primary: #6366F1 (Indigo)
- Secondary: #8B5CF6 (Purple)
- CTA: #10B981 (Emerald)
- Background: #F8FAFC (Slate 50)
- Text: #1E293B (Slate 800)

**Fintech:**
- Primary: #0EA5E9 (Sky Blue)
- Secondary: #14B8A6 (Teal)
- CTA: #F59E0B (Amber)
- Background: #FFFFFF
- Text: #0F172A (Slate 900)

### Step 4: Select Typography

Recommended font pairings:

| Pairing | Mood | Best For |
|---------|------|----------|
| Cormorant Garamond / Montserrat | Elegant, calming | Luxury, wellness, beauty |
| Inter / Inter | Clean, professional | SaaS, enterprise, dashboards |
| Poppins / Open Sans | Friendly, modern | Startups, apps, e-commerce |
| Playfair Display / Source Sans Pro | Sophisticated | Editorial, luxury brands |
| Space Grotesk / DM Sans | Tech-forward | Developer tools, AI products |

### Step 5: Apply Best Practices

**Always Include:**
- Smooth transitions (150-300ms)
- Hover states on interactive elements
- Focus states for keyboard navigation
- Responsive breakpoints: 375px, 768px, 1024px, 1440px
- WCAG AA contrast ratios (4.5:1 minimum)
- prefers-reduced-motion support

**Avoid (Anti-patterns):**
- Emojis as icons (use SVG icons instead)
- Missing cursor-pointer on clickable elements
- Harsh/jarring animations
- Poor color contrast
- Non-responsive layouts
