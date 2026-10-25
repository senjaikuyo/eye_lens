<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>Dashboard Admin | EyeLens</title>

    {{-- CSS --}}
    @vite([
        'resources/css/admin/sidebar.css',
        'resources/css/admin/dashboard.css'
    ])

    {{-- Google Font --}}
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>

    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">

    {{-- Lucide Icons --}}
    <script src="https://unpkg.com/lucide@latest"></script>
</head>


<body>

    {{-- SIDEBAR --}}
    @include('components.sidebar')


    {{-- MAIN CONTENT --}}
    <main class="main-content" id="mainContent">

        {{-- =========================
        HEADER
        ========================== --}}
        <header class="dashboard-header">

            <h1>Dashboard</h1>

            <p>Welcome Admin</p>

        </header>


        {{-- =========================
        STATISTIC CARDS
        ========================== --}}
        <section class="statistics">

            {{-- Total Activity --}}
            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">
                        <i data-lucide="activity"></i>
                    </div>

                    <span>Total Aktivitas</span>

                </div>

                <h2>1234</h2>

            </div>


            {{-- Today --}}
            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">
                        <i data-lucide="calendar-days"></i>
                    </div>

                    <span>Hari ini</span>

                </div>

                <h2>394</h2>

            </div>


            {{-- Total Feedback --}}
            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">
                        <i data-lucide="message-circle"></i>
                    </div>

                    <span>Total Feedback</span>

                </div>

                <h2>120</h2>

            </div>

        </section>


        {{-- =========================
        NEW ACTIVITY
        ========================== --}}
        <section class="dashboard-card">

            {{-- Card Header --}}
            <div class="card-header">

                <div>
                    <h3>New Activity</h3>

                    <p>
                        Aktivitas terbaru dari pengguna
                    </p>
                </div>

                <a href="#" class="view-all-button" title="Lihat semua aktivitas">
                    <i data-lucide="arrow-up-right"></i>
                </a>

            </div>


            {{-- Activity List --}}
            <div class="card-list">

                {{-- Activity 1 --}}
                <div class="list-item">

                    <div class="list-icon">
                        <i data-lucide="log-in"></i>
                    </div>

                    <div class="list-content">

                        <p class="list-title">
                            Login ke dalam Sistem
                        </p>

                        <p class="list-description">
                            Pengguna A
                        </p>

                    </div>

                    <span class="time-badge">
                        Baru saja
                    </span>

                </div>


                {{-- Activity 2 --}}
                <div class="list-item">

                    <div class="list-icon">
                        <i data-lucide="log-in"></i>
                    </div>

                    <div class="list-content">

                        <p class="list-title">
                            Login ke dalam Sistem
                        </p>

                        <p class="list-description">
                            Pengguna B
                        </p>

                    </div>

                    <span class="time-badge">
                        5 menit lalu
                    </span>

                </div>


                {{-- Activity 3 --}}
                <div class="list-item">

                    <div class="list-icon">
                        <i data-lucide="log-out"></i>
                    </div>

                    <div class="list-content">

                        <p class="list-title">
                            Logout dari Sistem
                        </p>

                        <p class="list-description">
                            Pengguna A
                        </p>

                    </div>

                    <span class="time-badge">
                        12 menit lalu
                    </span>

                </div>

            </div>

        </section>


        {{-- =========================
        NEW FEEDBACK
        ========================== --}}
        <section class="dashboard-card">

            {{-- Card Header --}}
            <div class="card-header">

                <div>

                    <h3>New Feedback</h3>

                    <p>
                        Feedback terbaru dari pengguna
                    </p>

                </div>

                <a href="#" class="view-all-button" title="Lihat semua feedback">
                    <i data-lucide="arrow-up-right"></i>
                </a>

            </div>


            {{-- Feedback List --}}
            <div class="card-list">

                {{-- Feedback 1 --}}
                <div class="list-item">

                    <div class="list-icon">
                        <i data-lucide="message-square-text"></i>
                    </div>

                    <div class="list-content">

                        <p class="list-title">
                            Akurasi pembacaan teksnya tepat
                        </p>

                        <p class="list-description">
                            Feedback dari pengguna
                        </p>

                    </div>

                    <span class="time-badge">
                        Hari ini
                    </span>

                </div>


                {{-- Feedback 2 --}}
                <div class="list-item">

                    <div class="list-icon">
                        <i data-lucide="message-square-text"></i>
                    </div>

                    <div class="list-content">

                        <p class="list-title">
                            Teks hasil pembacaan cukup jelas
                        </p>

                        <p class="list-description">
                            Feedback dari pengguna
                        </p>

                    </div>

                    <span class="time-badge">
                        Kemarin
                    </span>

                </div>


                {{-- Feedback 3 --}}
                <div class="list-item">

                    <div class="list-icon">
                        <i data-lucide="message-square-text"></i>
                    </div>

                    <div class="list-content">

                        <p class="list-title">
                            Tambahkan menu dari dokumen
                        </p>

                        <p class="list-description">
                            Feedback dari pengguna
                        </p>

                    </div>

                    <span class="time-badge">
                        3 hari lalu
                    </span>

                </div>

            </div>

        </section>

    </main>


    <script>

        lucide.createIcons();

        const sidebar =
            document.querySelector('.sidebar');

        const sidebarToggle =
            document.getElementById('sidebarToggle');

        const mainContent =
            document.getElementById('mainContent');


        sidebarToggle.addEventListener('click', function () {

            sidebar.classList.toggle('collapsed');

            mainContent.classList.toggle('expanded');

        });

    </script>

</body>

</html>