# updating on git

Pigs in space NetLogo model



---
# Git dlja 4ajnikov
to update the repo :

## do every time

```
git checkout master
git pull
ls
#after some changes in the folder
git status
git add .
git status
git commit -a -m "update `date +\"%Y-%m-%d\"`
"
#Review the changes and ensure they are satisfactory.
#Push the merge to your  repository.
git push
```


## do once

```
#in Windows install GitBash and start it
#in OSx just use terminal
#in OSx:
cd /Users/lizardie/Dropbox/MarinaTogerJohnOsth/Teaching/GIS2_VT2021/Projektarbete/git

#in all OS :
git init
#Initialized empty Git repository in /Users/lizardie/Dropbox/MarinaTogerJohnOsth/Teaching/GIS2_VT2021/Projektarbete/git/.git/
#config and setup
git config --global user.name "Lizardie"
git config --global user.email lizardie@gmail.com
git config --global core.excludesfile .gitignore

#git config https://github.com/lizardie/Pigs_In_Space.git
git clone https://github.com/lizardie/Pigs_In_Space.git
cd ..
ls -lah
rm -r .git
ls -lah
cd Pigs_In_Space
ls -lah
atom README.md
# edit the file and save
git status
git add .
git status

git commit -a -m 'first clone'
git push
```

`mv /Users/lizardie/Dropbox/MarinaTogerJohnOsth/Teaching/GIS2_VT2021/Projektarbete/PigsInSpace_model_2share/ /Users/lizardie/Dropbox/MarinaTogerJohnOsth/Teaching/GIS2_VT2021/Projektarbete/git/Pigs_In_Space`
