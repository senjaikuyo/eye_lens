<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>Log Activity | EyeLens</title>

    {{-- CSS --}}
    @vite([
        'resources/css/admin/sidebar.css',
        'resources/css/admin/logActivity.css'
    ])

    {{-- Google Font --}}
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>

    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">

    {{-- Lucide Icons --}}
    <script src="https://unpkg.com/lucide@latest"></script>
</head>

<body>

    {{-- Sidebar --}}
    @include('components.sidebar')


    {{-- Main Content --}}
    <main class="main-content" id="mainContent">

        {{-- Header --}}
        <header class="page-header">

            <h1>Log Activity</h1>

            <p>View user activity</p>

        </header>


        {{-- Statistics --}}
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


            {{-- Total User --}}
            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">
                        <i data-lucide="calendar-days"></i>
                    </div>

                    <span>Total Pengguna</span>

                </div>

                <h2>267</h2>

            </div>


            {{-- Today Activity --}}
            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">
                        <i data-lucide="message-circle"></i>
                    </div>

                    <span>Aktivitas Hari Ini</span>

                </div>

                <h2>122</h2>

            </div>

        </section>


        {{-- Activity History --}}
        <section class="activity-card">

            {{-- Title --}}
            <div class="activity-card-header">

                <div>
                    <h3>Activity History</h3>

                    <p>
                        Riwayat aktivitas pengguna EyeLens
                    </p>
                </div>

            </div>


            {{-- Toolbar --}}
            <div class="table-toolbar">

                {{-- Search --}}
                <div class="search-box">

                    <i data-lucide="search"></i>

                    <input type="text" id="searchInput" placeholder="Search by username...">

                </div>


                <div class="table-filters">

                    {{-- Activity Filter --}}
                    <div class="select-wrapper">

                        <i data-lucide="list-filter"></i>

                        <select id="activityFilter">

                            <option value="all">
                                All Activities
                            </option>

                            <option value="login">
                                Login
                            </option>

                            <option value="logout">
                                Logout
                            </option>

                        </select>

                    </div>


                    {{-- Date Filter --}}
                    <div class="select-wrapper date-filter">

                        <i data-lucide="calendar-days"></i>

                        <select>

                            <option>
                                Select Date Range
                            </option>

                            <option>
                                Today
                            </option>

                            <option>
                                Last 7 Days
                            </option>

                            <option>
                                Last 30 Days
                            </option>

                        </select>

                    </div>

                </div>

            </div>


            {{-- Table --}}
            <div class="table-container">

                <table class="activity-table">

                    <thead>

                        <tr>

                            <th class="time-column">
                                Time
                            </th>

                            <th class="user-column">
                                User
                            </th>

                            <th class="activity-column">
                                Log
                            </th>

                        </tr>

                    </thead>


                    <tbody id="activityTableBody">

                        <tr data-activity="login">

                            <td>

                                <div class="time-cell">

                                    <i data-lucide="clock-3"></i>

                                    <span>08:32</span>

                                </div>

                            </td>

                            <td>
                                Pengguna A
                            </td>

                            <td>

                                <div class="activity-log">

                                    <span class="activity-dot"></span>

                                    Login ke dalam Sistem

                                </div>

                            </td>

                        </tr>


                        <tr data-activity="login">

                            <td>

                                <div class="time-cell">

                                    <i data-lucide="clock-3"></i>

                                    <span>08:45</span>

                                </div>

                            </td>

                            <td>
                                Pengguna B
                            </td>

                            <td>

                                <div class="activity-log">

                                    <span class="activity-dot"></span>

                                    Login ke dalam Sistem

                                </div>

                            </td>

                        </tr>


                        <tr data-activity="logout">

                            <td>

                                <div class="time-cell">

                                    <i data-lucide="clock-3"></i>

                                    <span>09:12</span>

                                </div>

                            </td>

                            <td>
                                Pengguna A
                            </td>

                            <td>

                                <div class="activity-log">

                                    <span class="activity-dot"></span>

                                    Logout dari Sistem

                                </div>

                            </td>

                        </tr>


                        <tr data-activity="login">

                            <td>

                                <div class="time-cell">

                                    <i data-lucide="clock-3"></i>

                                    <span>09:24</span>

                                </div>

                            </td>

                            <td>
                                Pengguna C
                            </td>

                            <td>

                                <div class="activity-log">

                                    <span class="activity-dot"></span>

                                    Login ke dalam Sistem

                                </div>

                            </td>

                        </tr>


                        <tr data-activity="login">

                            <td>

                                <div class="time-cell">

                                    <i data-lucide="clock-3"></i>

                                    <span>10:05</span>

                                </div>

                            </td>

                            <td>
                                Pengguna D
                            </td>

                            <td>

                                <div class="activity-log">

                                    <span class="activity-dot"></span>

                                    Login ke dalam Sistem

                                </div>

                            </td>

                        </tr>


                        <tr data-activity="logout">

                            <td>

                                <div class="time-cell">

                                    <i data-lucide="clock-3"></i>

                                    <span>10:38</span>

                                </div>

                            </td>

                            <td>
                                Pengguna B
                            </td>

                            <td>

                                <div class="activity-log">

                                    <span class="activity-dot"></span>

                                    Logout dari Sistem

                                </div>

                            </td>

                        </tr>


                        <tr data-activity="login">

                            <td>

                                <div class="time-cell">

                                    <i data-lucide="clock-3"></i>

                                    <span>11:02</span>

                                </div>

                            </td>

                            <td>
                                Pengguna E
                            </td>

                            <td>

                                <div class="activity-log">

                                    <span class="activity-dot"></span>

                                    Login ke dalam Sistem

                                </div>

                            </td>

                        </tr>

                    </tbody>

                </table>

            </div>


            {{-- Table Footer --}}
            <div class="table-footer">

                <p>
                    Showing
                    <strong>1 - 7</strong>
                    of
                    <strong>173</strong>
                    entries
                </p>


                {{-- Pagination --}}
                <div class="pagination">

                    <button type="button">
                        <i data-lucide="chevron-left"></i>
                    </button>

                    <button type="button" class="active">
                        1
                    </button>

                    <button type="button">
                        2
                    </button>

                    <button type="button">
                        3
                    </button>

                    <button type="button">
                        <i data-lucide="chevron-right"></i>
                    </button>

                </div>

            </div>

        </section>

    </main>


    <script>

        lucide.createIcons();


        // =========================
        // SIDEBAR
        // =========================

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


        // =========================
        // SEARCH
        // =========================

        const searchInput =
            document.getElementById('searchInput');

        const activityFilter =
            document.getElementById('activityFilter');

        const rows =
            document.querySelectorAll(
                '#activityTableBody tr'
            );


        function filterTable() {

            const keyword =
                searchInput.value.toLowerCase();

            const selectedActivity =
                activityFilter.value;


            rows.forEach(function (row) {

                const rowText =
                    row.innerText.toLowerCase();

                const rowActivity =
                    row.dataset.activity;


                const matchesSearch =
                    rowText.includes(keyword);


                const matchesActivity =
                    selectedActivity === 'all' ||
                    rowActivity === selectedActivity;


                if (matchesSearch && matchesActivity) {

                    row.style.display = '';

                } else {

                    row.style.display = 'none';

                }

            });

        }


        searchInput.addEventListener(
            'input',
            filterTable
        );


        activityFilter.addEventListener(
            'change',
            filterTable
        );

    </script>

</body>

</html>