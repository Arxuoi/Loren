import importlib.util, io, tempfile, unittest
from contextlib import redirect_stdout
from pathlib import Path

P=Path(__file__).parents[1]/"nero/cli/nero.py"
s=importlib.util.spec_from_file_location("nero",P); nero=importlib.util.module_from_spec(s); s.loader.exec_module(nero)
class NeroCLI(unittest.TestCase):
 def test_presets(self):
  import json
  p=json.loads((Path(__file__).parents[1]/"nero/presets/presets.json").read_text())
  self.assertEqual(p["speed"],["-O3"]); self.assertEqual(p["kernel"],["-fnero-kernel"])
 def test_unknown_gki_is_honest(self):
  with tempfile.TemporaryDirectory() as d:
   Path(d,"Makefile").write_text("VERSION = 5\n")
   out=io.StringIO()
   with redirect_stdout(out): nero.cmd_gki(type("A",(),{"path":d})())
   self.assertIn("Toolchain version match: UNKNOWN",out.getvalue())
   self.assertIn("KMI validation: NOT RUN",out.getvalue())
 def test_all_targets(self): self.assertEqual(len(nero.TARGETS),7)
if __name__ == "__main__": unittest.main()
