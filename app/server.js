const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('🚀 i just installed a dynamic website using docker!');
});

app.listen(PORT, () => {
  console.log(`App running on port ${PORT}`);
});
