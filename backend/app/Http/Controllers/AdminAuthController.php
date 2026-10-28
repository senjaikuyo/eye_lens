<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;
use App\Models\AuditLog;
use App\Models\User;

class AdminAuthController extends Controller
{
    public function showLoginForm(): View|RedirectResponse
    {
        if (Auth::check() && Auth::user()->isAdmin()) {
            return redirect()->route('admin.dashboard');
        }

        return view('Auth.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $request->email)->first();

        if (Auth::attempt($credentials, $request->boolean('remember'))) {
            // Cek apakah user adalah admin
            if (!Auth::user()->isAdmin()) {

                // Catat log gagal karena bukan admin
                AuditLog::create([
                    'user_id' => Auth::id(),
                    'aktor' => Auth::user()->name ?? $request->email,
                    'aksi' => 'USER_LOGIN_FAILED',
                    'objek' => 'Admin Login Page',
                    'ip' => $request->ip(),
                    'user_agent' => $request->header('User-Agent'),
                    'keterangan' => 'Percobaan login ditolak: Kredensial tidak valid',
                    'result' => 'FAILED',
                    'timestamp' => now(),
                ]);

                Auth::logout();
                $request->session()->invalidate();
                $request->session()->regenerateToken();

                return back()
                    ->withErrors(['email' => 'Akses ditolak. Akun ini tidak memiliki hak akses administrator.'])
                    ->withInput($request->only('email'));
            }

            $request->session()->regenerate();

            // Catat log sukses
            AuditLog::create([
                'user_id' => Auth::id(),
                'aktor' => Auth::user()->name,
                'aksi' => 'USER_LOGIN_SUCCESS',
                'objek' => 'Admin Dashboard',
                'ip' => $request->ip(),
                'user_agent' => $request->header('User-Agent'),
                'keterangan' => 'Admin berhasil masuk ke dalam sistem',
                'result' => 'SUCCESS',
                'timestamp' => now(),
            ]);

            return redirect()->intended(route('admin.dashboard'));
        }

        // Catat log gagal karena salah email / password
        AuditLog::create([
            'user_id' => $user?->id ?? null,
            'aktor' => $request->email,
            'aksi' => 'USER_LOGIN_FAILED',
            'objek' => 'Admin Login Page',
            'ip' => $request->ip(),
            'user_agent' => $request->header('User-Agent'),
            'keterangan' => 'Percobaan login gagal karena kredensial tidak valid',
            'result' => 'FAILED',
            'timestamp' => now(),
        ]);

        return back()
            ->withErrors(['email' => 'Email atau password salah.'])
            ->withInput($request->only('email'));
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
