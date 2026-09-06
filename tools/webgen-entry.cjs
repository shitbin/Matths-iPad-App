const templates = require('./services/assessmentTemplates');
const { getProblemGenerator } = require('./services/problemGenerators');
const { generateValidProblem } = require('./services/problemGenerators/utils');
function tryGenerate(generate) {
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const p = generate();
      if (p?.prompt && p.answer !== undefined && p.answer !== null && String(p.answer).length) return p;
    } catch {}
  }
  return null;
}
const present = p => ({ prompt: p.prompt, choices: Array.isArray(p.choices) && p.choices.length ? p.choices : null,
  answer: String(p.answer), solution: p.solution || '', hintText: p.hintText || '', visualization: p.visualization || null });
globalThis.MatthsWebGen = {
  drawAdvanced(courseId, unitId, learned, count) {
    const config = (templates.unitConfigs || []).find(x => x.courseId === courseId && x.unitId === unitId);
    if (!config) return [];
    const learnedSet = new Set(learned || []);
    const eligible = config.advancedTemplates.filter(t => !learnedSet.size
      || (t.stages || []).some(s => (s.requiredConceptIds || []).every(id => learnedSet.has(id)))
      || (t.requiredConceptIds || []).every(id => learnedSet.has(id)));
    const pool = eligible.length ? eligible : config.advancedTemplates;
    const output = [], used = new Set();
    for (let tries = 0; output.length < count && tries < count * 8; tries++) {
      const t = pool[Math.floor(Math.random() * pool.length)];
      if (!t || (used.has(t.id) && used.size < pool.length)) continue;
      let generate = t.generate;
      for (const s of t.stages || []) if ((s.requiredConceptIds || []).every(id => learnedSet.has(id))) generate = s.generate;
      const p = tryGenerate(generate);
      if (!p) continue;
      used.add(t.id);
      output.push({ ...present(p), templateId: t.id, title: t.title || '', estimatedMinutes: t.estimatedMinutes || 8, sourcePattern: t.sourcePattern || '' });
    }
    return output;
  },
  conceptGeneratorInfo(courseId, unitId, conceptId) {
    const g = getProblemGenerator({ courseId, unitId, conceptId });
    return g ? { key: g.key, requiredDistinctTypes: g.requiredDistinctTypes || 5,
      types: (g.problemTypes || []).map(t => ({ id: t.id, label: t.label || '', difficulty: t.difficulty || 1 })) } : null;
  },
  generateLocal(courseId, unitId, conceptId, typeId, count) {
    const g = getProblemGenerator({ courseId, unitId, conceptId });
    const types = (g?.problemTypes || []).filter(t => !typeId || t.id === typeId);
    if (!types.length) return [];
    const output = [];
    for (let tries = 0; output.length < count && tries < count * 6; tries++) {
      const t = types[Math.floor(Math.random() * types.length)], p = tryGenerate(t.generate);
      if (p) output.push({ ...present(p), typeId: t.id, label: t.label || '', difficulty: t.difficulty || 1 });
    }
    return output;
  }
};
