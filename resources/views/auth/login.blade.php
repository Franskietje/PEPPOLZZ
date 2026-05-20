<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Login</title>
    <style>
        :root {
            --deep-navy: #0D1B2A;
            --sand: #B8865B;
            --paper: #F2F0EB;
            --white: #FFFFFF;
            --ink: #1B2636;
        }

        * { box-sizing: border-box; }

        body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            font-family: "Source Sans 3", "Segoe UI", sans-serif;
            background:
                radial-gradient(circle at 12% 20%, rgba(184, 134, 91, 0.22), rgba(184, 134, 91, 0) 36%),
                radial-gradient(circle at 88% 84%, rgba(13, 27, 42, 0.28), rgba(13, 27, 42, 0) 34%),
                linear-gradient(125deg, #08121d 0%, var(--deep-navy) 58%, #183147 100%);
            color: var(--paper);
            padding: 20px;
        }

        .card {
            width: 100%;
            max-width: 440px;
            background: rgba(9, 19, 31, 0.78);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 18px;
            box-shadow: 0 30px 60px rgba(0, 0, 0, 0.35);
            backdrop-filter: blur(6px);
            padding: 28px;
        }

        h1 {
            margin: 0 0 6px;
            font-size: 30px;
            font-family: "Playfair Display", Georgia, serif;
            letter-spacing: 0.01em;
        }

        .sub {
            margin: 0 0 22px;
            color: rgba(242, 240, 235, 0.76);
            font-size: 14px;
        }

        label {
            display: block;
            margin-bottom: 6px;
            font-size: 13px;
            letter-spacing: 0.03em;
            text-transform: uppercase;
            color: rgba(242, 240, 235, 0.8);
        }

        input[type="email"],
        input[type="password"] {
            width: 100%;
            border: 1px solid rgba(255, 255, 255, 0.2);
            background: rgba(255, 255, 255, 0.08);
            color: var(--white);
            border-radius: 11px;
            padding: 11px 12px;
            font-size: 15px;
            margin-bottom: 14px;
        }

        input::placeholder { color: rgba(255, 255, 255, 0.45); }

        .remember {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 16px;
            font-size: 14px;
            color: rgba(242, 240, 235, 0.9);
        }

        button {
            width: 100%;
            border: 0;
            border-radius: 11px;
            padding: 12px;
            font-size: 15px;
            font-weight: 700;
            background: linear-gradient(135deg, #C2915F, #A97246);
            color: #1a120a;
            cursor: pointer;
        }

        .error-box {
            margin: 0 0 14px;
            border-radius: 10px;
            border: 1px solid rgba(234, 94, 79, 0.62);
            background: rgba(234, 94, 79, 0.14);
            color: #ffd8d4;
            padding: 10px 12px;
            font-size: 14px;
        }
    </style>
</head>
<body>
<div class="card">
    <h1>Secure Login</h1>
    <p class="sub">Use your credentials to enter the invoicing portal.</p>

    @if ($errors->any())
        <div class="error-box">{{ $errors->first() }}</div>
    @endif

    <form method="post" action="{{ route('login') }}">
        @csrf

        <label for="email">Email</label>
        <input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus autocomplete="username" placeholder="you@company.com">

        <label for="password">Password</label>
        <input id="password" type="password" name="password" required autocomplete="current-password" placeholder="Your password">

        <label class="remember" for="remember">
            <input id="remember" type="checkbox" name="remember" value="1" {{ old('remember') ? 'checked' : '' }}>
            Keep me signed in
        </label>

        <button type="submit">Login</button>
    </form>
</div>
</body>
</html>
