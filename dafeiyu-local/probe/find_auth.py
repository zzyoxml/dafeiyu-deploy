import json
d = json.load(open("/AstrBot/data/cmd_config.json", encoding="utf-8-sig"))
def walk(o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            kl = str(k).lower()
            if any(w in kl for w in ("user", "pass", "jwt", "secret", "auth")):
                print(path + str(k), "=", str(v)[:70])
            walk(v, path + str(k) + ".")
walk(d)
print("---top keys---")
print(list(d.keys())[:40])
