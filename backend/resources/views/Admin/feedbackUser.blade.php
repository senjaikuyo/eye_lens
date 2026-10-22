<!DOCTYPE html>
<html lang="en">

<head>

    <meta charset="UTF-8">

    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>Feedback | EyeLens</title>


    @vite([
        'resources/css/admin/sidebar.css',
        'resources/css/admin/feedback.css'
    ])


    {{-- Google Font --}}

    <link rel="preconnect" href="https://fonts.googleapis.com">

    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>

    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">


    {{-- Lucide --}}

    <script src="https://unpkg.com/lucide@latest"></script>

</head>


<body>


    {{-- SIDEBAR --}}

    @include('components.sidebar')



    {{-- MAIN CONTENT --}}

    <main class="main-content" id="mainContent">


        {{-- HEADER --}}

        <header class="page-header">

            <h1>Feedback</h1>

            <p>
                View feedback from EyeLens users
            </p>

        </header>



        {{-- STATISTICS --}}

        <section class="statistics">


            {{-- TOTAL FEEDBACK --}}

            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">

                        <i data-lucide="message-circle"></i>

                    </div>

                    <span>Total Feedback</span>

                </div>

                <h2>120</h2>

            </div>



            {{-- TODAY --}}

            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">

                        <i data-lucide="calendar-days"></i>

                    </div>

                    <span>Feedback Hari Ini</span>

                </div>

                <h2>18</h2>

            </div>



            {{-- THIS WEEK --}}

            <div class="stat-card">

                <div class="stat-title">

                    <div class="stat-icon">

                        <i data-lucide="calendar-range"></i>

                    </div>

                    <span>Minggu Ini</span>

                </div>

                <h2>46</h2>

            </div>


        </section>



        {{-- FEEDBACK CONTAINER --}}

        <section class="feedback-card">


            {{-- HEADER --}}

            <div class="feedback-card-header">

                <div>

                    <h3>User Feedback</h3>

                    <p>
                        Feedback terbaru dari pengguna EyeLens
                    </p>

                </div>

            </div>



            {{-- TOOLBAR --}}

            <div class="feedback-toolbar">


                {{-- SEARCH --}}

                <div class="search-box">

                    <i data-lucide="search"></i>

                    <input type="text" id="feedbackSearch" placeholder="Search feedback...">

                </div>



                {{-- FILTER --}}

                <div class="select-wrapper">

                    <i data-lucide="list-filter"></i>

                    <select>

                        <option>
                            All Feedback
                        </option>

                        <option>
                            Today
                        </option>

                        <option>
                            This Week
                        </option>

                    </select>

                </div>


            </div>



            {{-- FEEDBACK LIST --}}

            <div class="feedback-list" id="feedbackList">


                {{-- FEEDBACK 1 --}}

                <article class="feedback-item">

                    <div class="feedback-avatar">

                        <i data-lucide="user"></i>

                    </div>


                    <div class="feedback-content">

                        <div class="feedback-user">

                            <h4>Pengguna A</h4>

                            <span>Hari ini, 10:42</span>

                        </div>


                        <p>
                            Akurasi pembacaan teksnya tepat dan
                            hasil suara cukup jelas.
                        </p>

                    </div>


                    <button type="button" class="feedback-action">

                        <i data-lucide="ellipsis"></i>

                    </button>

                </article>



                {{-- FEEDBACK 2 --}}

                <article class="feedback-item">

                    <div class="feedback-avatar">

                        <i data-lucide="user"></i>

                    </div>


                    <div class="feedback-content">

                        <div class="feedback-user">

                            <h4>Pengguna B</h4>

                            <span>Kemarin, 16:20</span>

                        </div>


                        <p>
                            Teks hasil pembacaan cukup jelas.
                            Fitur pembesaran juga sangat membantu.
                        </p>

                    </div>


                    <button type="button" class="feedback-action">

                        <i data-lucide="ellipsis"></i>

                    </button>

                </article>



                {{-- FEEDBACK 3 --}}

                <article class="feedback-item">

                    <div class="feedback-avatar">

                        <i data-lucide="user"></i>

                    </div>


                    <div class="feedback-content">

                        <div class="feedback-user">

                            <h4>Pengguna C</h4>

                            <span>3 hari yang lalu</span>

                        </div>


                        <p>
                            Mungkin bisa ditambahkan fitur untuk
                            membaca teks langsung dari dokumen.
                        </p>

                    </div>


                    <button type="button" class="feedback-action">

                        <i data-lucide="ellipsis"></i>

                    </button>

                </article>



                {{-- FEEDBACK 4 --}}

                <article class="feedback-item">

                    <div class="feedback-avatar">

                        <i data-lucide="user"></i>

                    </div>


                    <div class="feedback-content">

                        <div class="feedback-user">

                            <h4>Pengguna D</h4>

                            <span>5 hari yang lalu</span>

                        </div>


                        <p>
                            Aplikasinya mudah digunakan dan
                            tampilan kameranya cukup sederhana.
                        </p>

                    </div>


                    <button type="button" class="feedback-action">

                        <i data-lucide="ellipsis"></i>

                    </button>

                </article>


            </div>



            {{-- FOOTER --}}

            <div class="feedback-footer">

                <p>
                    Showing
                    <strong>1 - 4</strong>
                    of
                    <strong>120</strong>
                    feedback
                </p>


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


        // ======================================
        // SIDEBAR
        // ======================================

        const sidebar =
            document.querySelector('.sidebar');

        const sidebarToggle =
            document.getElementById('sidebarToggle');

        const mainContent =
            document.getElementById('mainContent');


        sidebarToggle.addEventListener(
            'click',
            function () {

                sidebar.classList.toggle('collapsed');

                mainContent.classList.toggle('expanded');

            }
        );



        // ======================================
        // SEARCH FEEDBACK
        // ======================================

        const searchInput =
            document.getElementById('feedbackSearch');

        const feedbackItems =
            document.querySelectorAll('.feedback-item');


        searchInput.addEventListener(
            'input',
            function () {

                const keyword =
                    searchInput.value.toLowerCase();


                feedbackItems.forEach(function (item) {

                    const content =
                        item.innerText.toLowerCase();


                    if (content.includes(keyword)) {

                        item.style.display = 'flex';

                    } else {

                        item.style.display = 'none';

                    }

                });

            }
        );

    </script>


</body>

</html>