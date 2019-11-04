# PREPARATION

1) Rebase enhancement branch with master
```bash
git checkout master
git pull
git checkout enhancement
git rebase master
git push origin enhancement -f
```

2) Create merge request to merge enhancement to master (do not delete source branch!!!)

# PLATFORM RELEASE

1) Create platform release tag and push to origin (gitlab)

```bash
git tag -a PLATFORM-VERSION-TAG -m "Teamwire on-premise platform release PLATFORM-VERSION-TAG 2019"
```

2) Push the created tag to origin (gitlab)

```bash
git push origin PLATFORM-VERSION-TAG
```

3) Push the created tag to github
```bash
git push github PLATFORM-VERSION-TAG
```


