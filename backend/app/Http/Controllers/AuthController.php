<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use App\Models\AuditLog;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => [
                'required',
                'string',
                'confirmed',
                Password::min(8)
                    ->letters()
                    ->mixedCase()
                    ->numbers()
                    ->symbols(),
            ],
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Registration successful',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
            'access_token' => $token,
            'token_type' => 'Bearer',
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        $user = User::where('email', $request->email)->first();

        // 1. Kondisi jika Login Gagal (Password salah atau User tidak ditemukan)
        if (!$user || !Hash::check($request->password, $user->password)) {

            // Catat log gagal ke tabel audit_log
            AuditLog::create([
                'user_id' => $user?->id ?? null,
                'aktor' => $request->email,
                'aksi' => 'USER_LOGIN_FAILED',
                'objek' => 'Mobile Login API',
                'ip' => $request->ip(),
                'user_agent' => $request->header('User-Agent'),
                'keterangan' => 'Percobaan login mobile gagal karena kredensial tidak valid',
                'result' => 'FAILED',
                'timestamp' => now(),
            ]);

            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        // 2. Kondisi jika Login Berhasil
        $token = $user->createToken('auth_token')->plainTextToken;

        // Catat log sukses ke tabel audit_log
        AuditLog::create([
            'user_id' => $user->id,
            'aktor' => $user->name,
            'aksi' => 'USER_LOGIN_SUCCESS',
            'objek' => 'Mobile Login API',
            'ip' => $request->ip(),
            'user_agent' => $request->header('User-Agent'),
            'keterangan' => 'User mobile berhasil masuk ke dalam sistem',
            'result' => 'SUCCESS',
            'timestamp' => now(),
        ]);

        return response()->json([
            'message' => 'Login successful',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
            'access_token' => $token,
            'token_type' => 'Bearer',
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $request->user(),
        ]);
    }
}
