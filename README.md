# brew-migrate.sh
A terminal script to quickly list any apps installed manually that can be found in brew

## What the Script Does

1. **Identifies applications**: The script finds applications installed manually in `/Applications` and `~/Applications` that can be installed using Homebrew.

2. **Creates a list file**: It saves the list of migratable applications to `~/brew_migratable_apps.txt` in the format `path_to_app:brew_package_name`.

3. **Preserves settings**: When installing with Homebrew, application settings and data are preserved since Homebrew doesn't remove the application's data folders in your home directory.

## How to Use the Script

1. **Basic usage** - Just finds applications and creates the list:
   ```bash
   ./brew_migrate.sh
   ```

2. **Force refresh** - Updates all application and brew package lists:
   ```bash
   ./brew_migrate.sh -r
   ```

3. **Install with Homebrew** - Finds applications and offers to install them:
   ```bash
   ./brew_migrate.sh -i
   ```

4. **Force refresh and install** - Combines both options:
   ```bash
   ./brew_migrate.sh -r -i
   ```

## How Application Settings are Preserved

When you install applications with Homebrew after previously having them installed manually:

1. User settings and data for most macOS applications are stored in:
   - `~/Library/Application Support/[App Name]`
   - `~/Library/Preferences/[App Bundle ID].plist`
   - `~/Library/Caches/[App Name]`

2. Homebrew cask installations respect these existing settings folders and don't overwrite them.

3. When you run an application installed by Homebrew for the first time, it will automatically detect and use your existing settings.

## Notes on the Implementation

- The script uses cross-platform compatible commands so it should work on both macOS and Linux.
- It caches the application and brew lists in `/tmp` to avoid unnecessary repeated searches.
- When finding matches in Homebrew, it prioritizes exact matches over partial matches.
- For applications with multiple potential Homebrew matches, it notes that in the output file.

To run the script, navigate to your dotfiles directory and execute it with your desired options!
