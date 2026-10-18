# Problèmes connus · Known issues · 已知问题

À corriger dans une prochaine version. · To be fixed in an upcoming version. · 计划在后续版本中修复。

## 1. Les résultats des tests interactifs restent dans la langue d'origine

**Concerne / Affects / 影响版本 :** 1.0.0, 1.0.1

**FR —** Les résultats des tests interactifs (clavier, écran, haut-parleurs, micro, caméra, Touch ID, trackpad, test de charge, vitesse disque, ports) sont enregistrés sous forme de texte déjà traduit. Après un changement de langue, ils restent dans la langue active au moment du test. Exemple : test du clavier effectué en français, interface passée en anglais → la ligne « Keyboard » de la vue d'ensemble affiche toujours « Touches possiblement bloquées : ⌘, ⇧… ». Contournement : refaire le test après avoir changé de langue.

**EN —** Interactive test results are stored as already-translated text, so after switching the interface language they stay in the language that was active when the test was run. Workaround: run the test again after switching language.

**中文 —** 交互测试的结论在测试时就生成为当时语言的文字，切换界面语言后不会跟着变。例如在法语下做的键盘测试，切到英文后，概览页「Keyboard」一行仍显示法语结论。临时办法：切换语言后重新测试一次。

**Piste de correction / Fix idea / 修复思路 :** store each result as a message key plus arguments (for example `keyboard.stuck` + key names) instead of the final string, and translate it when displaying; apply the same to history snapshots and exported reports. Previously saved snapshots keep their stored text.

改为保存「文案键 + 参数」，显示时再翻译；历史记录和导出报告同样处理，已保存的旧快照保持原文。
