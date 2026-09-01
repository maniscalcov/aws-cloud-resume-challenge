/**
 * Wires up the portfolio's contact form (section#four) to submit via
 * fetch() instead of a normal page POST, so it works against the
 * API Gateway + Lambda + SES backend.
 *
 * Usage: add before </body>, after the other asset scripts:
 *   <script src="assets/js/contact.js" defer></script>
 */
(function () {
  'use strict';

  const API_URL = 'https://mjo31xn1h1.execute-api.us-east-2.amazonaws.com/contact';

  const form = document.querySelector('#four form');
  if (!form) return;

  const submitBtn = form.querySelector('input[type="submit"]');

  const status = document.createElement('p');
  status.id = 'contact-status';
  status.style.display = 'none';
  status.style.marginTop = '1em';
  form.appendChild(status);

  function showStatus(text, isError) {
    status.textContent = text;
    status.style.color = isError ? '#c0392b' : '#27ae60';
    status.style.display = 'block';
  }

  form.addEventListener('submit', async function (e) {
    e.preventDefault();

    const name = form.querySelector('#name').value.trim();
    const email = form.querySelector('#email').value.trim();
    const subject = form.querySelector('#subject').value.trim();
    const message = form.querySelector('#message').value.trim();

    if (!name || !email || !subject || !message) {
      showStatus('Please fill out all fields.', true);
      return;
    }

    submitBtn.disabled = true;
    submitBtn.value = 'Sending...';
    status.style.display = 'none';

    try {
      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, subject, message }),
      });

      const data = await res.json().catch(function () { return null; });

      if (!res.ok) {
        showStatus((data && data.error) || 'Something went wrong. Please try again.', true);
        return;
      }

      showStatus("Thanks — your message has been sent. I'll get back to you soon.", false);
      form.reset();
    } catch (err) {
      showStatus("Couldn't reach the server. Check your connection and try again.", true);
    } finally {
      submitBtn.disabled = false;
      submitBtn.value = 'Send Message';
    }
  });
})();