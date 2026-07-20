let audioCtx = null;

// Helper to initialize AudioContext on user interaction if browser suspends it
function initAudio() {
    if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
}

// Function to generate a realistic police radio dispatch alert sound
function playBackupSound(urgency) {
    try {
        initAudio();
        
        const now = audioCtx.currentTime;
        
        // 1. Play static radio burst (noise)
        playRadioNoise(now, 0.08, 0.03); // Quick crackle at start
        
        if (urgency === 'high') { // BK 1 - Maximum Importance Siren Beeps
            // Urgent 3-chirp high-pitched alarm
            for (let i = 0; i < 3; i++) {
                const start = now + (i * 0.18) + 0.05;
                playTone(1350, start, 0.08, 'triangle', 0.2);
                playTone(1650, start + 0.08, 0.08, 'sine', 0.15);
            }
            // End crackle
            playRadioNoise(now + 0.6, 0.1, 0.02);
        } else if (urgency === 'medium') { // BK 2 & 3 - Medium Urgency
            // Dual-tone high-low alert chirp
            playTone(950, now + 0.05, 0.08, 'sine', 0.25);
            playTone(750, now + 0.13, 0.12, 'sine', 0.2);
            // End crackle
            playRadioNoise(now + 0.28, 0.08, 0.02);
        } else { // BK 4 & 5 - Low Urgency
            // Simple neat dispatcher notification chime
            playTone(880, now + 0.05, 0.15, 'sine', 0.2);
            // End crackle
            playRadioNoise(now + 0.22, 0.06, 0.02);
        }
    } catch (e) {
        console.error("Web Audio API failed to play sound:", e);
    }
}

// Helper to play a clean synthesizer tone
function playTone(freq, startTime, duration, type, volume) {
    const osc = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();
    
    osc.type = type;
    osc.frequency.setValueAtTime(freq, startTime);
    
    gainNode.gain.setValueAtTime(volume, startTime);
    // Smooth fade out to prevent clicks
    gainNode.gain.exponentialRampToValueAtTime(0.0001, startTime + duration);
    
    osc.connect(gainNode);
    gainNode.connect(audioCtx.destination);
    
    osc.start(startTime);
    osc.stop(startTime + duration);
}

// Helper to simulate radio static/white noise crackle
function playRadioNoise(startTime, duration, volume) {
    const bufferSize = audioCtx.sampleRate * duration;
    const buffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
    const data = buffer.getChannelData(0);
    
    // Fill buffer with random values (white noise)
    for (let i = 0; i < bufferSize; i++) {
        data[i] = Math.random() * 2 - 1;
    }
    
    const noiseNode = audioCtx.createBufferSource();
    noiseNode.buffer = buffer;
    
    // Add bandpass filter to sound like radio speaker
    const filter = audioCtx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(1000, startTime);
    filter.Q.setValueAtTime(1.5, startTime);
    
    const gainNode = audioCtx.createGain();
    gainNode.gain.setValueAtTime(volume, startTime);
    gainNode.gain.exponentialRampToValueAtTime(0.0001, startTime + duration);
    
    noiseNode.connect(filter);
    filter.connect(gainNode);
    gainNode.connect(audioCtx.destination);
    
    noiseNode.start(startTime);
    noiseNode.stop(startTime + duration);
}

// Listen for messages from FiveM client
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'showBackup') {
        // Initialize audio context on first received alert (user interaction is simulated in NUI)
        initAudio();
        
        // Play corresponding sound based on backup level urgency
        playBackupSound(data.urgency);
        
        // Create HTML notification card
        const container = document.getElementById('notifications-container');
        
        // If there's an existing active backup card from this officer for this specific level, remove it first
        const existingCard = document.querySelector(`.backup-card[data-sender-id="${data.id}-${data.level}"]`);
        if (existingCard) {
            existingCard.remove();
        }

        const card = document.createElement('div');
        card.className = 'backup-card';
        card.setAttribute('data-sender-id', `${data.id}-${data.level}`);
        
        // Bind the level color RGB values to CSS custom property
        card.style.setProperty('--level-rgb', data.colorRgb);
        
        // Sanitize and convert details to uppercase
        const officerName = toUppercaseSafe(data.name);
        const streetAndZone = toUppercaseSafe(`${data.street}, ${data.zone}`);
        const descriptionText = toUppercaseSafe(data.title);
        
        card.innerHTML = `
            <div class="backup-row-top">
                <div class="backup-tag">
                    <div class="backup-tag-bullet"></div>
                    <span>${data.levelLabel}</span>
                </div>
                <div class="backup-officer-info">- ${officerName} (${data.id})</div>
            </div>
            <div class="backup-row-middle">${descriptionText}</div>
            <div class="backup-row-bottom">
                <svg class="location-pin-icon" viewBox="0 0 24 24">
                    <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
                </svg>
                <span>${streetAndZone}</span>
            </div>
        `;
        
        // Append card to container
        container.appendChild(card);
    } 
    else if (data.action === 'clearBackup') {
        // Find and remove the backup card for the specified officer and level
        const card = document.querySelector(`.backup-card[data-sender-id="${data.id}-${data.level}"]`);
        if (card) {
            card.classList.add('hide');
            
            // Remove from DOM after transition completes (matching style.css animation)
            setTimeout(function() {
                card.remove();
            }, 400);
        }
    }
});

// Helper function to safely convert standard string or numbers to uppercase
function toUppercaseSafe(val) {
    if (!val) return "";
    return String(val).toUpperCase();
}
