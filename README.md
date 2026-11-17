# Prompt Picker

A single-page tool for browsing, randomizing and copying anime image-generation prompts.

- Pick any character from a dropdown, filtered by game, gender and name.
- **Random character**: a random prompt from the current filters.
- **True random**: builds one prompt from five different characters, one per section
  (face, body, clothes, pose, body type). Gender "Any" mixes men and women freely;
  Female or Male keeps every section to that gender. Tick **keep** to hold a section,
  or **Reroll** to change just one.
- **Copy prompt** puts the finished prompt on your clipboard.

Everything runs in the browser. There is no server and nothing is sent anywhere.

## Files

| File | What it is |
|---|---|
| `index.html` | The site. All prompts are built into it. |
| `All_Prompts.txt` | The prompt source. |
| `template.html` | The page without the prompts. |
| `build.ps1` | Puts `All_Prompts.txt` into `template.html` and writes `index.html`. |

## Updating the prompts

1. Edit `All_Prompts.txt`.
2. Run `powershell -ExecutionPolicy Bypass -File build.ps1` in this folder.
3. Upload the new `index.html` (and `All_Prompts.txt`) to the repository.

You can also try an edited file without rebuilding: open the site, go to
**Settings → Load an updated All_Prompts.txt**.
