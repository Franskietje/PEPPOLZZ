<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Attributes\AsCommand;
use Illuminate\Console\Command;

#[AsCommand(name: 'user:upsert')]
class UpsertUserCommand extends Command
{
    protected $signature = 'user:upsert
        {email : The user email address}
        {name? : The display name}
        {--password= : The password to set for the user}';

    protected $description = 'Create a user account or reset an existing user password';

    public function handle(): int
    {
        $email = mb_strtolower(trim((string) $this->argument('email')));
        $name = trim((string) ($this->argument('name') ?: 'Administrator'));
        $password = (string) ($this->option('password') ?: $this->secret('Password'));

        if ($password === '') {
            $this->error('Password is required.');

            return self::FAILURE;
        }

        $user = User::firstOrNew(['email' => $email]);
        $user->name = $user->exists ? ($name !== '' ? $name : $user->name) : $name;
        $user->password = $password;
        $user->save();

        $this->info($user->wasRecentlyCreated
            ? 'User created successfully.'
            : 'User updated successfully.');

        $this->line('Email: '.$user->email);

        return self::SUCCESS;
    }
}