let images = [];
let index = 0;

function initGallery(imgList) {
  images = imgList;
  index = 0;

  const viewer = document.getElementById("viewer");
  const thumbs = document.getElementById("thumbs");

  thumbs.innerHTML = "";

  images.forEach((src, i) => {
    const t = document.createElement("img");
    t.src = src;
    t.onclick = () => show(i);
    thumbs.appendChild(t);
  });

  show(0);

  document.addEventListener("keydown", e => {
    if (e.key === "ArrowRight") next();
    if (e.key === "ArrowLeft") prev();
  });
}

function show(i) {
  index = i;
  document.getElementById("main").src = images[i];

  document.querySelectorAll(".thumbs img").forEach((t, j) =>
    t.classList.toggle("active", j === i)
  );
}

function next() {
  show((index + 1) % images.length);
}

function prev() {
  show((index - 1 + images.length) % images.length);
}
