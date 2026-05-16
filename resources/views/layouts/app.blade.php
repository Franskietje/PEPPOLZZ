<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'franssiss BV' }}</title>
    <link rel="icon" type="image/png" href="{{ asset('brand/franssiss_favicon_32.png') }}">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Playfair+Display:wght@600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --deep-navy: #0D1B2A;
            --deep-navy-soft: #152538;
            --charcoal: #1F2328;
            --warm-bronze: #B8865B;
            --warm-bronze-soft: #D7B291;
            --cool-gray: #8A96A3;
            --light-gray: #E7EAEE;
            --off-white: #F7F7F5;
            --white: #FFFFFF;
            --text: var(--charcoal);
            --muted: #677380;
            --line: rgba(13, 27, 42, 0.11);
            --surface: rgba(255, 255, 255, 0.92);
            --surface-strong: #ffffff;
            --surface-tint: #f2f0eb;
            --shadow: 0 24px 60px rgba(13, 27, 42, 0.10);
            --shadow-soft: 0 18px 40px rgba(13, 27, 42, 0.08);
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            color: var(--text);
            line-height: 1.6;
            font-family: "Inter", Arial, sans-serif;
            background:
                radial-gradient(circle at top left, rgba(184, 134, 91, 0.15) 0%, rgba(184, 134, 91, 0) 32%),
                radial-gradient(circle at 85% 12%, rgba(138, 150, 163, 0.16) 0%, rgba(138, 150, 163, 0) 24%),
                linear-gradient(180deg, #fbfaf8 0%, var(--off-white) 48%, #f3f1ec 100%);
            min-height: 100vh;
        }
        body::before {
            content: "";
            position: fixed;
            inset: 0;
            pointer-events: none;
            background-image:
                linear-gradient(rgba(13, 27, 42, 0.02) 1px, transparent 1px),
                linear-gradient(90deg, rgba(13, 27, 42, 0.02) 1px, transparent 1px);
            background-size: 28px 28px;
            mask-image: linear-gradient(180deg, rgba(0, 0, 0, 0.28), rgba(0, 0, 0, 0));
        }
        header {
            position: sticky;
            top: 0;
            z-index: 30;
            color: var(--white);
            background:
                linear-gradient(135deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0)),
                linear-gradient(115deg, #08121d 0%, var(--deep-navy) 55%, #16293c 100%);
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
            box-shadow: 0 16px 36px rgba(13, 27, 42, 0.24);
            backdrop-filter: blur(14px);
        }
        .header-rail {
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
            color: rgba(247, 247, 245, 0.75);
            font-size: 11px;
            letter-spacing: 0.24em;
            text-transform: uppercase;
        }
        .header-rail-inner {
            max-width: 1220px;
            margin: 0 auto;
            padding: 10px 18px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
        }
        .top-nav {
            max-width: 1220px;
            margin: 0 auto;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 20px;
            padding: 16px 18px;
        }
        .brand {
            display: flex;
            align-items: center;
            gap: 16px;
            min-width: 0;
            text-decoration: none;
            color: inherit;
        }
        .brand-mark {
            width: 220px;
            max-width: 100%;
            height: auto;
            display: block;
        }
        .brand-copy {
            display: flex;
            flex-direction: column;
            gap: 2px;
            min-width: 0;
        }
        .brand-label {
            color: rgba(247, 247, 245, 0.84);
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.22em;
            white-space: nowrap;
        }
        .brand-tagline {
            color: rgba(231, 234, 238, 0.78);
            font-size: 13px;
            white-space: nowrap;
        }
        .nav-links {
            display: flex;
            align-items: center;
            flex-wrap: wrap;
            justify-content: flex-end;
            gap: 8px;
        }
        .nav-link {
            color: rgba(247, 247, 245, 0.82);
            text-decoration: none;
            font-weight: 600;
            font-size: 13px;
            letter-spacing: 0.04em;
            text-transform: uppercase;
            padding: 10px 12px;
            border-radius: 999px;
            border: 1px solid rgba(255, 255, 255, 0.06);
            transition: .18s ease;
        }
        .nav-link:hover {
            background: rgba(255, 255, 255, 0.08);
            border-color: rgba(184, 134, 91, 0.36);
            color: var(--white);
        }
        .nav-link.active {
            background: rgba(184, 134, 91, 0.18);
            border-color: rgba(184, 134, 91, 0.54);
            color: var(--white);
            box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.05);
        }
        main {
            max-width: 1220px;
            margin: 34px auto 40px;
            padding: 0 18px 28px;
        }
        .card {
            background: linear-gradient(180deg, rgba(255, 255, 255, 0.97) 0%, rgba(255, 255, 255, 0.9) 100%);
            border-radius: 24px;
            padding: 24px;
            box-shadow: var(--shadow);
            border: 1px solid rgba(13, 27, 42, 0.08);
            margin-bottom: 20px;
            overflow: hidden;
            position: relative;
        }
        .card::after {
            content: "";
            position: absolute;
            inset: 0;
            pointer-events: none;
            background: linear-gradient(145deg, rgba(184, 134, 91, 0.06), rgba(184, 134, 91, 0) 22%);
        }
        .card > * {
            position: relative;
            z-index: 1;
        }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; }
        .stat {
            font-size: 40px;
            font-weight: 700;
            letter-spacing: -0.04em;
            font-family: "Playfair Display", Georgia, serif;
            color: var(--deep-navy);
        }
        .stat-card {
            background:
                radial-gradient(circle at top right, rgba(184, 134, 91, 0.16), rgba(184, 134, 91, 0) 34%),
                linear-gradient(180deg, rgba(255, 255, 255, 0.98) 0%, rgba(242, 240, 235, 0.92) 100%);
            border: 1px solid rgba(184, 134, 91, 0.18);
            box-shadow: var(--shadow-soft);
        }
        .card > table {
            width: 100%;
            border-collapse: collapse;
            background: transparent;
            display: block;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            min-width: 680px;
        }
        th, td { padding: 14px 12px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }
        th { color: var(--cool-gray); font-size: 11px; text-transform: uppercase; letter-spacing: 0.14em; font-weight: 700; }
        td { color: var(--charcoal); }
        tbody tr:hover td { background: rgba(184, 134, 91, 0.05); }
        h1, h2, h3 {
            margin-top: 0;
            color: var(--deep-navy);
            font-family: "Playfair Display", Georgia, serif;
            letter-spacing: -0.03em;
        }
        h1 { font-size: clamp(2rem, 4vw, 3.5rem); line-height: 1.05; margin-bottom: 12px; }
        h2 { font-size: 24px; margin-bottom: 12px; }
        h3 { font-size: 18px; }
        p { margin-top: 0; }
        input, select, textarea {
            width: 100%;
            padding: 12px 14px;
            border: 1px solid rgba(13, 27, 42, 0.12);
            border-radius: 16px;
            font: inherit;
            color: var(--charcoal);
            background: rgba(255, 255, 255, 0.9);
            transition: border-color .18s ease, box-shadow .18s ease, background .18s ease;
        }
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: rgba(184, 134, 91, 0.9);
            background: var(--white);
            box-shadow: 0 0 0 4px rgba(184, 134, 91, 0.16);
        }
        label {
            display: block;
            font-weight: 700;
            margin-bottom: 8px;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.12em;
            color: var(--deep-navy);
        }
        .field { margin-bottom: 16px; }
        .button, button {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border: 0;
            background: var(--warm-bronze);
            color: var(--white);
            padding: 11px 16px;
            border-radius: 999px;
            text-decoration: none;
            font-weight: 700;
            letter-spacing: 0.02em;
            cursor: pointer;
            transition: .18s ease;
            box-shadow: 0 10px 24px rgba(184, 134, 91, 0.22);
        }
        .button:hover, button:hover {
            background: #a97347;
            transform: translateY(-1px);
            box-shadow: 0 14px 28px rgba(184, 134, 91, 0.26);
        }
        .button.secondary, button.secondary {
            background: rgba(13, 27, 42, 0.92);
            box-shadow: 0 10px 24px rgba(13, 27, 42, 0.18);
        }
        .button.secondary:hover, button.secondary:hover { background: var(--deep-navy-soft); }
        .button.danger, button.danger {
            background: #8c2f35;
            box-shadow: 0 10px 24px rgba(140, 47, 53, 0.18);
        }
        .button.danger:hover, button.danger:hover { background: #78262c; }
        .muted { color: var(--muted); }
        .success {
            background: rgba(28, 119, 74, 0.08);
            border: 1px solid rgba(28, 119, 74, 0.18);
            color: #17603f;
            padding: 14px 16px;
            border-radius: 18px;
            margin-bottom: 16px;
        }
        .errors {
            background: rgba(140, 47, 53, 0.08);
            border: 1px solid rgba(140, 47, 53, 0.18);
            color: #7b242a;
            padding: 14px 16px;
            border-radius: 18px;
            margin-bottom: 16px;
        }
        .actions { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
        .actions h1, .actions h2 { margin-bottom: 0; margin-right: auto; }
        .right { text-align: right; }
        .status-badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 700;
            text-transform: capitalize;
            background: rgba(13, 27, 42, 0.08);
            color: var(--deep-navy);
            border: 1px solid rgba(13, 27, 42, 0.1);
        }
        .status-draft, .status-needs_review {
            background: rgba(184, 134, 91, 0.14);
            color: #7a5331;
            border-color: rgba(184, 134, 91, 0.28);
        }
        .status-approved, .status-paid {
            background: rgba(28, 119, 74, 0.10);
            color: #17603f;
            border-color: rgba(28, 119, 74, 0.20);
        }
        .status-rejected, .status-cancelled {
            background: rgba(140, 47, 53, 0.10);
            color: #7b242a;
            border-color: rgba(140, 47, 53, 0.20);
        }
        .status-ready, .status-validated, .status-sent, .status-processed {
            background: rgba(13, 27, 42, 0.08);
            color: var(--deep-navy);
            border-color: rgba(13, 27, 42, 0.14);
        }
        .page-eyebrow {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            color: var(--warm-bronze);
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.22em;
            text-transform: uppercase;
            margin-bottom: 14px;
        }
        .page-eyebrow::before {
            content: "";
            width: 42px;
            height: 1px;
            background: rgba(184, 134, 91, 0.5);
        }
        .hero-card {
            padding: 30px;
            background:
                radial-gradient(circle at top right, rgba(184, 134, 91, 0.16), rgba(184, 134, 91, 0) 30%),
                linear-gradient(120deg, rgba(13, 27, 42, 0.96) 0%, rgba(13, 27, 42, 0.9) 50%, rgba(21, 37, 56, 0.96) 100%);
            color: var(--white);
            border: 1px solid rgba(255, 255, 255, 0.06);
        }
        .hero-card::after {
            background:
                linear-gradient(145deg, rgba(184, 134, 91, 0.12), rgba(184, 134, 91, 0) 24%),
                radial-gradient(circle at 85% 15%, rgba(255, 255, 255, 0.08), rgba(255, 255, 255, 0) 24%);
        }
        .hero-card h1,
        .hero-card h2,
        .hero-card h3,
        .hero-card p,
        .hero-card .muted {
            color: inherit;
        }
        .hero-card .page-eyebrow {
            color: var(--warm-bronze-soft);
        }
        .hero-card .page-eyebrow::before {
            background: rgba(215, 178, 145, 0.48);
        }
        .hero-grid {
            display: grid;
            grid-template-columns: minmax(0, 1.4fr) minmax(260px, 0.8fr);
            gap: 28px;
            align-items: end;
        }
        .hero-panel {
            padding: 20px;
            border-radius: 20px;
            background: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.08);
            backdrop-filter: blur(10px);
        }
        .metric-label {
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.18em;
            color: var(--cool-gray);
            margin-bottom: 6px;
        }
        .metric-value {
            font-size: 26px;
            font-family: "Playfair Display", Georgia, serif;
            color: var(--deep-navy);
        }
        .split-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 16px;
        }
        code {
            padding: 2px 7px;
            border-radius: 999px;
            background: rgba(13, 27, 42, 0.06);
            color: var(--deep-navy);
            font-size: 0.92em;
        }

        @media (max-width: 700px) {
            .header-rail { display: none; }
            .top-nav {
                align-items: flex-start;
                flex-direction: column;
                padding: 14px 12px;
            }
            .brand {
                width: 100%;
                flex-direction: column;
                align-items: flex-start;
                gap: 10px;
            }
            .brand-mark { width: min(210px, 72vw); }
            .brand-copy { gap: 4px; }
            .brand-tagline { white-space: normal; }
            .nav-links { width: 100%; }
            .nav-link { font-size: 12px; padding: 9px 11px; }
            main { margin: 16px auto 22px; padding: 0 12px 16px; }
            .card { padding: 16px; border-radius: 18px; }
            .stat { font-size: 32px; }
            .actions { align-items: stretch; }
            .actions > a,
            .actions > form,
            .actions > button,
            .actions > h1,
            .actions > h2 {
                width: 100%;
                margin-right: 0 !important;
            }
            .actions .button,
            .actions button {
                width: 100%;
                text-align: center;
            }
            .hero-grid { grid-template-columns: 1fr; gap: 16px; }
            .hero-card { padding: 18px; }
            .right { text-align: left; }
            th, td { padding: 10px; }
        }
    </style>
</head>
<body>
<header>
    <div class="header-rail">
        <div class="header-rail-inner">
            <span>franssiss BV</span>
            <span>Clean. Strategic. Reliable.</span>
        </div>
    </div>
    <nav class="top-nav">
        <a class="brand" href="{{ route('web.dashboard') }}">
            <img class="brand-mark" src="{{ asset('brand/franssiss_logo_primary_light.svg') }}" alt="franssiss BV">
            <span class="brand-copy">
                <span class="brand-label">Management &amp; Consultancy</span>
                <span class="brand-tagline">Helder advies. Duurzame impact.</span>
            </span>
        </a>
        <div class="nav-links">
            <a class="nav-link {{ request()->routeIs('web.dashboard') ? 'active' : '' }}" href="{{ route('web.dashboard') }}">Dashboard</a>
            <a class="nav-link {{ request()->routeIs('web.invoices.*') ? 'active' : '' }}" href="{{ route('web.invoices.index') }}">Sales</a>
            <a class="nav-link {{ request()->routeIs('web.incoming-invoices.*') ? 'active' : '' }}" href="{{ route('web.incoming-invoices.index') }}">Incoming</a>
            <a class="nav-link {{ request()->routeIs('web.receipts.*') ? 'active' : '' }}" href="{{ route('web.receipts.index') }}">Receipts</a>
            <a class="nav-link {{ request()->routeIs('web.contacts.*') ? 'active' : '' }}" href="{{ route('web.contacts.index') }}">Contacts</a>
            <a class="nav-link {{ request()->routeIs('web.products.*') ? 'active' : '' }}" href="{{ route('web.products.index') }}">Products</a>
            <a class="nav-link {{ request()->routeIs('web.company.*') ? 'active' : '' }}" href="{{ route('web.company.edit') }}">Company</a>
        </div>
    </nav>
</header>
<main>
    @if (session('success'))
        <div class="success">{{ session('success') }}</div>
    @endif

    @if ($errors->any())
        <div class="errors">
            <strong>Please fix this:</strong>
            <ul>
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    @yield('content')
</main>
</body>
</html>
