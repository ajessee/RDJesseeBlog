(function () {
  function showError(form, message, destination) {
    let notice = form.querySelector('[data-upload-error]');
    if (!notice) {
      notice = document.createElement('p');
      notice.setAttribute('data-upload-error', '');
      notice.setAttribute('role', 'alert');
      notice.className = 'alert alert-danger';
      form.appendChild(notice);
    }
    notice.textContent = message;
    if (destination) {
      const link = document.createElement('a');
      link.href = destination;
      link.textContent = ' View saved recording';
      notice.appendChild(link);
    }
  }

  function upload(form, data, button) {
    button.disabled = true;
    $.ajax({
      url: form.action, type: 'POST', data: data, dataType: 'json',
      processData: false, contentType: false
    }).done(function (result) {
      window.location.href = result.redirect_url;
    }).fail(function (response) {
      const result = response.responseJSON || {};
      showError(form, result.error || 'Upload failed. Please try again.', result.redirect_url);
    }).always(function () { button.disabled = false; });
  }

  const uploadForm = document.querySelector('[data-id="new-audio-upload-form"]');
  if (uploadForm) {
    uploadForm.addEventListener('submit', function (event) {
      event.preventDefault();
      upload(uploadForm, new FormData(uploadForm), uploadForm.querySelector('[type="submit"]'));
    });
  }

  const showButton = document.querySelector('#show-recorder');
  if (!showButton) return;
  const container = document.querySelector('#audio-recorder');
  const buttons = document.querySelector('#recording-buttons');
  const start = document.querySelector('#start-audio-recorder');
  const stop = document.querySelector('#stop-audio-recorder');
  const submit = document.querySelector('#submit-recording-button');
  const form = document.querySelector('[data-id="new-audio-recording-form"]');
  let recorder, stream, recordedBlob, audioURL;

  function releaseMicrophone() {
    if (stream) stream.getTracks().forEach(function (track) { track.stop(); });
    stream = null;
  }

  showButton.onclick = function () {
    showButton.style.display = 'none';
    container.style.display = 'inline-block';
    submit.style.display = 'none';
    stop.style.display = 'none';
  };

  start.onclick = async function () {
    if (!navigator.mediaDevices || !window.MediaRecorder) {
      showError(form, 'This browser cannot record audio. Please upload an audio file instead.');
      return;
    }
    start.disabled = true;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const type = ['audio/webm;codecs=opus', 'audio/mp4', 'audio/ogg;codecs=opus'].find(function (value) {
        return MediaRecorder.isTypeSupported(value);
      });
      recorder = type ? new MediaRecorder(stream, { mimeType: type }) : new MediaRecorder(stream);
      const chunks = [];
      recorder.ondataavailable = function (event) { if (event.data.size) chunks.push(event.data); };
      recorder.onerror = function () {
        releaseMicrophone();
        start.disabled = false;
        showError(form, 'Recording failed. Please try again or upload a file.');
      };
      recorder.onstop = function () {
        releaseMicrophone();
        start.disabled = false;
        start.classList.remove('recording-pulse');
        start.textContent = 'Start New Recording';
        stop.style.display = 'none';
        if (!chunks.length) return showError(form, 'No audio was captured. Please try again.');
        if (audioURL) URL.revokeObjectURL(audioURL);
        const previous = buttons.querySelector('.audio-clip');
        if (previous) previous.remove();
        recordedBlob = new Blob(chunks, { type: recorder.mimeType });
        audioURL = URL.createObjectURL(recordedBlob);
        const clip = document.createElement('div');
        clip.className = 'audio-clip';
        const audio = document.createElement('audio');
        audio.controls = true;
        audio.src = audioURL;
        const caption = document.createElement('p');
        caption.id = 'recording-caption';
        caption.contentEditable = true;
        caption.textContent = prompt('Enter a caption for your recording:') || 'Recorded memory';
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.className = 'btn btn-danger';
        remove.textContent = 'Delete Current Recording';
        remove.onclick = function () {
          URL.revokeObjectURL(audioURL);
          recordedBlob = null;
          clip.remove();
          submit.style.display = 'none';
        };
        clip.append(audio, caption, remove);
        buttons.appendChild(clip);
        submit.style.display = 'inline-block';
      };
      recorder.start();
      start.textContent = 'Recording';
      start.classList.add('recording-pulse');
      stop.disabled = false;
      stop.style.display = 'inline-block';
    } catch (error) {
      releaseMicrophone();
      start.disabled = false;
      showError(form, 'Microphone access was unavailable. Try again or upload an audio file.');
    }
  };
  stop.onclick = function () { if (recorder && recorder.state === 'recording') recorder.stop(); };
  form.addEventListener('submit', function (event) {
    event.preventDefault();
    if (!recordedBlob) return showError(form, 'Record some audio first.');
    const data = new FormData(form);
    const extension = recordedBlob.type.includes('mp4') ? 'm4a' : recordedBlob.type.includes('ogg') ? 'ogg' : 'webm';
    data.append('recording[audio_file]', recordedBlob, 'recording.' + extension);
    data.append('recording[caption]', document.querySelector('#recording-caption').textContent);
    upload(form, data, submit);
  });
  window.addEventListener('pagehide', releaseMicrophone);
})();
