<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>Login Admin | EyeLens</title>

    @vite('resources/css/auth/login.css')

    {{-- Google Font --}}
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>

    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">

    {{-- Lucide Icons --}}
    <script src="https://unpkg.com/lucide@latest"></script>
</head>

<body>

    <main class="login-container">

        <div class="login-card">

            {{-- Logo --}}
            <div class="logo">
                <div class="logo-symbol">
                    e
                </div>

                <span class="logo-text">
                    eyeLens
                </span>
            </div>


            {{-- Heading --}}
            <h1>Welcome to EyeLens</h1>

            <p class="subtitle">
                Please log in to continue.
            </p>


            {{-- Form --}}
            <form id="loginForm" method="POST" action="{{ route('admin.login.submit') }}">
                @csrf

                {{-- Email --}}
                <div class="input-group">
                    <i data-lucide="user-round" class="input-icon"></i>
                    <input type="email" id="email" name="email" value="{{ old('email') }}" placeholder="Email" required autofocus>
                </div>


                {{-- Password --}}
                <div class="input-group">
                    <i data-lucide="lock-keyhole" class="input-icon"></i>
                    <input type="password" id="password" name="password" placeholder="Password" required>

                    <button type="button" class="password-toggle" id="passwordToggle">
                        <i data-lucide="eye" id="eyeIcon"></i>
                    </button>
                </div>


                {{-- Error Message --}}
                @if ($errors->any())
                    <p id="loginError" class="login-error" style="display: block;">
                        {{ $errors->first() }}
                    </p>
                @endif


                {{-- Login Button --}}
                <div class="button-wrapper">
                    <button type="submit" class="login-button">
                        Login
                    </button>
                </div>

            </form>

        </div>

    </main>


    <script>
        lucide.createIcons();

        // =========================
        // SHOW / HIDE PASSWORD
        // =========================
        const passwordInput = document.getElementById('password');
        const passwordToggle = document.getElementById('passwordToggle');

        if (passwordToggle && passwordInput) {
            passwordToggle.addEventListener('click', function () {
                const eyeIcon = document.getElementById('eyeIcon');
                if (passwordInput.type === 'password') {
                    passwordInput.type = 'text';
                    eyeIcon.setAttribute('data-lucide', 'eye-off');
                } else {
                    passwordInput.type = 'password';
                    eyeIcon.setAttribute('data-lucide', 'eye');
                }
                lucide.createIcons();
            });
        }
    </script>

</body>

</html>
