# try-emap
Try out EMAP using tools available on the UCLH Data Science Desktop


## Setting up R

See the example `.Rprofile` and `.Renviron` files in `example-config-files`

- CRAN installs should just work
- `remotes::install_github` requires the config set-up as above


## Setting up git

Install using https://git-scm.com/download/win
Then you have Git Bash in the start menu
Then set up ~/.gitconfig using the example file. Git needs the proxy addresses in the .gitconfig file to work. You can check this using `git config --global --list`.

I seemed to be able to get my credentials stored by using the bash shell from VSCode. Open a terminal and then choose Git Bash as your default shell (e.g. `E:\UserProfiles\USERNAME\AppData\Local\Programs\Git\bin\bash.exe`). You can update this in settings:

```
{
    "terminal.integrated.shell.windows": "E:\\UserProfiles\\USERNAME\\AppData\\Local\\Programs\\Git\\bin\\bash.exe"
}
```

Now the first time you try to git clone it will open an interactive window where you can enter your username and password.

Note
- drives in git bash are found at `/driveletter/`
- your home directory (Documents) is found at `/DRIVELETTER/UserProfiles/USERNAME` (e.g. `/e/UserProfiles/sharris9`)

## Setting up DBForge

## Putting it all together

Let's log on to the UDS ...
