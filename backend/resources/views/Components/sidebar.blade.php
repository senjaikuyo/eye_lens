<aside class="sidebar">

    {{-- Header / Logo --}}
    <div class="sidebar-header">

        <div class="sidebar-logo">
            <div class="sidebar-logo-symbol">e</div>
            <span>eyeLens</span>
        </div>

        <button type="button" class="sidebar-toggle" id="sidebarToggle">
            <i data-lucide="chevron-left"></i>
        </button>

    </div>


    {{-- Navigation --}}
    <nav class="sidebar-nav">

        {{-- Dashboard --}}
        <a href="{{ route('admin.dashboard') }}"
            class="sidebar-item {{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">
            <i data-lucide="house"></i>
            <span>Dashboard</span>
        </a>


        {{-- Log Activity --}}
        <a href="{{ route('admin.logActivity') }}"
            class="sidebar-item {{ request()->routeIs('admin.logActivity') ? 'active' : '' }}">
            <i data-lucide="clock-3"></i>
            <span>Log Activity</span>
        </a>


        {{-- Feedback --}}
        <a href="{{ route('admin.feedback') }}"
            class="sidebar-item {{ request()->routeIs('admin.feedback') ? 'active' : '' }}">
            <i data-lucide="message-circle"></i>
            <span>Feedback</span>
        </a>

    </nav>


    {{-- Logout --}}
    <div class="sidebar-footer">

        <a href="/" class="logout-button">

            <span>Logout</span>

            <i data-lucide="log-out"></i>

        </a>

    </div>

</aside>